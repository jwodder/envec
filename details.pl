#!/usr/bin/perl -w
# Things this script needs to do:
#  - Remove italics from flavor text and watermarks [done]
#  - Convert short set names to long set names [done]
#  - Convert rarities from single characters to full words [done]
#  - Tag split, flip, and double-faced cards as such [done]
#  - Unmung munged flip cards [done]
#  - Merge halves of split cards [done]
#  - Handle the duplicate printings entries for Invasion-block split cards
#    [done by joinPrintings]
#  - Fix Homura's Essence and any other flip cards they've messed up recently
#    [done]
#  - For the Ascendant/Essence cycle, remove the P/T values from the bottom
#    halves [done]
#  - Incorporate data/rarities.tsv (adding an "old-rarity" field to Printing.pm)
#  - Make sure nothing from data/tokens.txt (primarily the Unglued tokens)
#    slipped through
#  - Somehow handle split cards with differing artists for each half
use strict;
use Getopt::Std;
use LWP::Simple;
use POSIX 'strftime';
use EnVec ':all';
use EnVec::Util;
use EnVec::Card::Util;

use Carp;
$SIG{__DIE__}  = sub { Carp::confess(@_) };
$SIG{__WARN__} = sub { Carp::cluck(@_) };

my %rarities = (C => 'Common',
		U => 'Uncommon',
		R => 'Rare',
		M => 'Mythic Rare',
		L => 'Land',
		P => 'Promo',
		S => 'Special');

my %opts;
getopts('C:S:j:x:l:I:', \%opts) || exit 2;
loadSets($opts{S});
loadParts;

my $log;
if (!exists $opts{l} || $opts{l} eq '-') { $log = *STDERR }
else { open $log, '>', $opts{l} or die "$0: $opts{l}: $!" }
select((select($log), $| = 1)[0]);

my %cardIDs;
if (exists $opts{C}) {
 my $in = openR($opts{C}, $0);
 while (<$in>) {
  chomp;
  next if /^\s*#/ || /^\s*$/;
  my($card, $id) = split /\t+/;
  $cardIDs{$card} = $id if !exists $cardIDs{$card};
 }
 close $in;
} else {
 for my $set (setsToImport) {
  print $log "Importing $set...\n";
  my $list = get "http://gatherer.wizards.com/Pages/Search/Default.aspx?output=checklist&set=[%22$set%22]&special=true";
  print STDERR "Could not fetch $set\n" and next if !defined $list;
  for my $c (parseChecklist $list) {
   $cardIDs{$c->{name}} = $c->{multiverseid} if !exists $cardIDs{$c->{name}}
  }
 }
}
print $log scalar(keys %cardIDs), " cards imported\n";
delete $cardIDs{$_} for flipBottoms, doubleBacks;
print $log scalar(keys %cardIDs), " cards to fetch\n\n";

if ($opts{I}) {
 open my $ids, '>', $opts{I} or die "$0: $opts{I}: $!";
 print $ids "$_\t$cardIDs{$_}\n" for sort keys %cardIDs;
 exit 0;
}

my %badflip;
if (open my $bf, '<', 'data/badflip.txt') {
 local $/ = "\n----\n";
 while (<$bf>) {
  chomp;
  my($name, $type, $pt, @text) = split /\n/;
  my($supers, $types, $subs) = parseTypes $type;
  my($pow, $tough) = $pt ? (map { simplify $_ } split m:/:, $pt, 2) : ();
  $badflip{alternate $name} = new EnVec::Card::Content name => $name,
   supertypes => $supers, types => $types, subtypes => $subs, pow => $pow,
   tough => $tough, text => join("\n", @text);
 }
}

my $json = openW($opts{j} || 'out/details.json', $0);
print $json "[\n";

my $xml  = openW($opts{x} || 'out/details.xml',  $0);
print $xml '<?xml version="1.0" encoding="UTF-8"?>', "\n";
#print $xml '<!DOCTYPE cardlist SYSTEM "../../mtgcard.dtd">', "\n";
print $xml "<cardlist date=\"", strftime('%Y-%m-%d', gmtime), "\">\n\n";

print $log "Fetching individual card data...\n";
my %split;
my $first = 1;
for my $name (sort keys %cardIDs) {
 if (!isSplit $name) {if ($first) { $first = 0 } else { print $json ",\n\n" } }
 my @ids = ($cardIDs{$name});
 my(%seen, $card, @printings);
 while (@ids) {
  my $id = shift @ids;
  print $log "$name/$id\n";
  my $url = "http://gatherer.wizards.com/Pages/Card/Details.aspx?multiverseid=$id" . (isSplit $name && "&part=$name");
  my $details = get $url;
  print STDERR "Could not fetch $name/$id\n" and next if !defined $details;
  my $prnt = parseDetails $details;
  if (isFlip $name) {
   if (($prnt->text || '') =~ /^----$/m) { $prnt = unmungFlip $prnt }
   else {
    $prnt->cardClass(FLIP_CARD);
    # Manually fix some flip card entries that Gatherer just can't seem to get
    # right:
    if (exists $badflip{$prnt->part1->name}) {
     # Should this not replace part2's that are already present?  If so, how
     # should Homura's Essence be handled?
     my $part2 = $badflip{$prnt->part1->name};
     $part2->cost($prnt->cost);
     $prnt->content([ $prnt->part1, $part2 ]);
    }
    if ($prnt->part1->name =~ /^[^\s,]+, \w+ Ascendant$/) {
     $prnt->part2->pow(undef);
     $prnt->part2->tough(undef);
    }
   }
  } elsif (isDouble $name) { $prnt->cardClass(DOUBLE_CARD) }
  $card = $prnt if !defined $card;
   ### When $card is defined, should this check that it equals $prnt?
  if (!%seen) {
   $seen{$id} = 1;
   my @newIDs;
   if (isDouble $name) {
    # As double-faced cards have separate multiverseids for each face, we're
    # going to assume that if you've seen any IDs for one set, you've seen them
    # all for that set, and if you haven't seen any for a set, you'll still
    # only get to see one.
    my %setIDs;
    push @{$setIDs{$_->set}}, $_->multiverseid->all for @{$prnt->printings};
    for my $set (keys %setIDs) {
     if (grep { $_ eq $id } @{$setIDs{$set}}) { $setIDs{$set} = [] }
     elsif (@{$setIDs{$set}}) { $setIDs{$set} = [ $setIDs{$set}[0] ] }
    }
    @newIDs = map { @$_ } values %setIDs;
   } else { @newIDs = map { $_->multiverseid->all } @{$prnt->printings} }
   for (@newIDs) { push @ids, $_ and $seen{$_} = 1 if !$seen{$_} }
  }
  ### Assume that the printing currently being fetched is the only one that has
  ### an "artist" field: (Try to make this more robust?)
  my($newPrnt) = grep { $_->artist->any } @{$prnt->printings};
  my $set = fromAbbrev($newPrnt->set);
  if (defined $set) { $newPrnt->set($set) }
  else { print STDERR "Unknown set \"", $newPrnt->set, "\" for $name/$id\n" }
  if (defined $newPrnt->rarity) {
   if (exists $rarities{$newPrnt->rarity}) {
    $newPrnt->rarity($rarities{$newPrnt->rarity})
   } else {
    print STDERR "Unknown rarity \"", $newPrnt->rarity, "\" for $name/$id\n"
   }
  }
  $newPrnt->flavor($newPrnt->flavor->mapvals(\&rmitalics));
  $newPrnt->watermark($newPrnt->watermark->mapvals(\&rmitalics));
  push @printings, $newPrnt;
 }
 if (defined $card) { # in case no printings can be fetched
  $card->printings([ sortPrintings @printings ]);
  if (isSplit $name) { $split{$name} = $card }
  else {print $json $card->toJSON; print $xml $card->toXML, "\n"; }
 }
}

print $log "Joining split cards...\n";
for (splits) {
 my($left, $right) = @{$_}{'primary','secondary'};
 if (!exists $split{$left} || !exists $split{$right}) {
  print STDERR "Split card mismatch: $left was found but $right was not\n"
   if exists $split{$left};
  print STDERR "Split card mismatch: $right was found but $left was not\n"
   if exists $split{$right};
  next;
 }
 if ($first) { $first = 0 }
 else { print $json ",\n\n" }
 my $card = joinCards SPLIT_CARD, $split{$left}, $split{$right};
 print $json $card->toJSON;
 print $xml $card->toXML, "\n";
}

print $json "\n]\n";
print $xml "</cardlist>\n";
print $log "Done.\n";

sub rmitalics {my $str = shift; $str =~ s:</?i>::gi; return $str; }

#!/usr/bin/perl -w
# Things this script still needs to do:
#  - Incorporate data/rarities.tsv (adding an "old-rarity" field to Printing.pm)
#  - Make sure nothing from data/tokens.txt (primarily the Unglued tokens)
#    slipped through
#  - Somehow handle split cards with differing artists for each half
#  - Give the multiple printing entries for B.F.M. and the split cards in
#    Invasion and Apocalypse (caused by having two multiverseids each) the same
#    (or similar?) treatment that DFCs get
use strict;
use Encode 'encode_utf8', 'is_utf8';
use Getopt::Std;
use LWP::Simple;
use POSIX 'strftime';
use EnVec ':all';
use EnVec::Util;
use EnVec::Card::Util;

use Carp;
$SIG{__DIE__}  = sub { Carp::confess(@_) };
$SIG{__WARN__} = sub { Carp::cluck(@_) };

sub rmitalics($);
sub getURL($);
sub ending();
sub logmsg(@);

my %rarities = (C => 'Common',
		U => 'Uncommon',
		R => 'Rare',
		M => 'Mythic Rare',
		L => 'Land',
		P => 'Promo',
		S => 'Special');

my(@missed, %opts);
getopts('C:S:j:x:l:i:I:', \%opts) || exit 2;
loadSets($opts{S});
loadParts;
open STDERR, '>', $opts{l} or die "$0: $opts{l}: $!"
 if exists $opts{l} && $opts{l} ne '-';
select((select(STDERR), $| = 1)[0]);

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
  logmsg "FETCHING SET $set";
  my $list = getURL "http://gatherer.wizards.com/Pages/Search/Default.aspx?output=checklist&action=advanced&set=[%22$set%22]&special=true";
  if (defined $list) {
   my @cards = parseChecklist $list;
   if (@cards) {
    for my $c (@cards) {
     $cardIDs{$c->{name}} = $c->{multiverseid} if !exists $cardIDs{$c->{name}}
    }
   } else { logmsg "ERROR: No cards in set $set???" }
  } else {
   logmsg "ERROR: Could not fetch set $set";
   push @missed, "SET $set";
  }
 }
}
logmsg "INFO: ", scalar(keys %cardIDs), " card names imported";
delete $cardIDs{$_} for splitRights, flipBottoms, doubleBacks;
logmsg "INFO: ", scalar(keys %cardIDs), " cards to fetch";

if ($opts{i} || $opts{I}) {
 my $out = $opts{I} || $opts{i};
 open my $ids, '>', $out or die "$0: $out: $!";
 print $ids "$_\t$cardIDs{$_}\n" for sort keys %cardIDs;
 logmsg "INFO: Card IDs written to $out";
 ending if $opts{I};
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

logmsg "INFO: Fetching individual card data...";
my $first = 1;
for my $name (sort keys %cardIDs) {
 if ($first) { $first = 0 }
 else { print $json ",\n\n" }
 my @ids = ($cardIDs{$name});
 my(%seen, $card, @printings);
 while (@ids) {
  my $id = shift @ids;
  logmsg "FETCHING CARD $name/$id";
  my $url = "http://gatherer.wizards.com/Pages/Card/Details.aspx?multiverseid=$id" . (isSplit $name && "&part=$name");
  # As of 2013 July 10, despite the fact that split cards in Gatherer now have
  # both halves on a single page like flip & double-faced cards, you still need
  # to append "&part=$name" to the end of their URLs or else the page may
  # non-deterministically display the halves in the wrong order.
  my $details = getURL $url;
  if (!defined $details) {
   logmsg "ERROR: Could not fetch card $name/$id";
   push @missed, "CARD $name/$id";
   next;
  }
  my $prnt = parseDetails $details;
  ### This needs to detect flip & double-faced cards that are missing parts.
  if (isSplit $name) { $prnt->cardClass(SPLIT_CARD) }
  elsif (isFlip $name) {
   if (($prnt->text || '') =~ /^----$/m) { $prnt = unmungFlip $prnt }
   else {
    $prnt->cardClass(FLIP_CARD);
    # Manually fix some flip card entries that Gatherer just can't seem to get
    # right:
    if (exists $badflip{$prnt->part1->name}) {
     # Should this not replace part2's that are already present?
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
  else { logmsg "ERROR: Unknown set \"", $newPrnt->set, "\" for $name/$id" }
  if (defined $newPrnt->rarity) {
   if (exists $rarities{$newPrnt->rarity}) {
    $newPrnt->rarity($rarities{$newPrnt->rarity})
   } else {
    logmsg "ERROR: Unknown rarity \"", $newPrnt->rarity, "\" for $name/$id"
   }
  }
  $newPrnt->flavor($newPrnt->flavor->mapvals(\&rmitalics));
  $newPrnt->watermark($newPrnt->watermark->mapvals(\&rmitalics));
  push @printings, $newPrnt;
 }
 if (defined $card) { # in case no printings can be fetched
  $card->printings([ sortPrintings @printings ]);
  print $json $card->toJSON;
  print $xml $card->toXML, "\n";
 }
}

print $json "\n]\n";
print $xml "</cardlist>\n";
ending;

sub rmitalics($) {my $str = shift; $str =~ s:<i>\s*|\s*</i>::gi; return $str; }

sub getURL($) {
 my $data = get $_[0];
 $data = encode_utf8 $data if defined $data && is_utf8($data);
 return $data;
}

sub ending() {
 if (@missed) {
  my $misfile;
  if (open $misfile, '>', 'missed.txt') {
   print $misfile "$_\n" for @missed;
   close $misfile;
  } else {
   logmsg "ERROR: Could not write to missed.txt: $!";
   logmsg "MISSED: $_" for @missed;
  }
  logmsg "INFO: Failed to fetch ", scalar(@missed), " item", @missed > 1 && 's';
  logmsg "DONE";
  exit 1;
 } else {logmsg 'DONE'; exit 0; }
}

sub logmsg(@) { print STDERR time, ' ', @_, "\n" }

__END__

Tasks this script takes care of:
 - Remove italics from flavor text and watermarks
 - Convert short set names to long set names
 - Convert rarities from single characters to full words
 - Tag split, flip, and double-faced cards as such
 - Unmung munged flip cards
 - Handle the duplicate printings entries for Invasion-block split cards (done
   by joinPrintings)
 - Apply the fixes from badflip.txt
 - For the Ascendant/Essence cycle, remove the P/T values from the bottom
   halves

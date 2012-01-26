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
#  - For the Ascendant/Essence cycle, remove the mana costs and P/T values from
#    the bottom halves.
#  - Fix Homura's Essence
#  - Incorporate data/rarities.tsv (with affected rarities changed to the form
#    "Common (C1)"?)
use strict;
use Getopt::Std;
use LWP::Simple;
use EnVec ':all';
use EnVec::Util;
use EnVec::Card::Util;

use Carp;
$SIG{__DIE__} = sub { Carp::confess(@_) };
$SIG{__WARN__} = sub { Carp::cluck(@_) };

my %rarities = (C => 'Common', U => 'Uncommon', R => 'Rare', M => 'Mythic Rare', L => 'Land', P => 'Promo', S => 'Special');

my %opts;
getopts('C:S:j:x:l:', \%opts) || exit 2;
loadSets($opts{S} || 'data/sets.tsv');
loadParts;

$opts{j} ||= 'out/details.json';
open my $json, '>', $opts{j} or die "$0: $opts{j}: $!";

$opts{x} ||= 'out/details.xml';
open my $xml, '>', $opts{x} or die "$0: $opts{x}: $!";

my $log;
if (!exists $opts{l} || $opts{l} eq '-') { $log = *STDERR }
else { open $log, '>', $opts{l} or die "$0: $opts{l}: $!" }
select((select($log), $| = 1)[0]);

my %cardIDs = ();
if (exists $opts{C}) {
 open my $in, '<', $opts{C} or die "$0: $opts{C}: $!";
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
  my $list = get(checklistURL $set);
  print STDERR "Could not fetch $set\n" and next if !defined $list;
  for my $c (parseChecklist $list) {
   $cardIDs{$c->{name}} = $c->{multiverseid} if !exists $cardIDs{$c->{name}}
  }
 }
}

print $log scalar(keys %cardIDs), " cards imported\n\n";

delete $cardIDs{$_} for flipBottoms, doubleBacks;

print $log "Fetching individual card data...\n";
print $json "[\n";
print $xml "<cardlist>\n\n";  ### Include date attribute?
my %split = ();
my $first = 1;

for my $name (sort keys %cardIDs) {
 if (!isSplit $name) {
  if ($first) { $first = 0 }
  else { print $json ",\n\n" }
 }
 my @ids = ($cardIDs{$name});
 my %seen = ($cardIDs{$name} => 1);
 my $card = undef;
 my @printings = ();
 while (@ids) {
  my $id = shift @ids;
  print $log "$name/$id\n";
  my $details = get(isSplit $name ? detailsURL($id, $name) : detailsURL($id));
  print STDERR "Could not fetch $name/$id\n" and next if !defined $details;
  my $prnt = parseDetails $details;
  if (isFlip $name) {
   if (($prnt->text || '') =~ /^----$/) { $prnt = unmungFlip $prnt }
   else { $prnt->cardType(FLIP_CARD) }
  } elsif (isDouble $name) { $prnt->cardType(DOUBLE_CARD) }
  if (!defined $card) { $card = $prnt }
  ### else { ensure $card == $prnt } ???
  for (map { $_->multiverseid->all } @{$prnt->printings}) {
   push @ids, $_ and $seen{$_} = 1 if !$seen{$_}
  }
  ### Assume that the printing currently being fetched is the only one that has
  ### an "artist" field: (Try to make this more robust?)
  my($newPrnt) = grep { $_->artist->any } @{$prnt->printings};
  # Convert set abbreviations to long names:
  my $set = fromAbbrev($newPrnt->set);
  if (defined $set) { $newPrnt->set($set) }
  else {
   print STDERR "Unknown set abbreviation \"", $newPrnt->set,
    "\" for $name/$id\n"
  }
  # Convert rarity abbreviations to long names:
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
 $card->printings([ sortPrintings @printings ]);
 if (isSplit $name) { $split{$name} = $card }
 else {print $json $card->toJSON; print $xml $card->toXML, "\n"; }
}

print $log "Joining split cards...\n";
for my $left (splitLefts) {  # splitLefts is already sorted.
 my $right = alternate $left;
 if (!exists $split{$left} || !exists $split{$right}) {
  print STDERR "Split card mismatch: $left was found but $right was not\n"
   if exists $split{$left};
  print STDERR "Split card mismatch: $right was found but $left was not\n"
   if exists $split{$right};
  next;
 }
 if ($first) { $first = 0 }
 else { print $json ",\n\n" }
 my $card = joinCards SPLIT_CARD, $left, $right;
 print $json $card->toJSON;
 print $xml $card->toXML, "\n";
}

print $json "\n]\n";
print $xml "</cardlist>\n";

sub rmitalics {
 my $str = shift;
 $str =~ s:</?i>::gi;
 return $str;
}

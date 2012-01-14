#!/usr/bin/perl -w

# Things this script needs to do:
#  - Tag split, flip, and double-faced cards as such
#  - Unmung munged flip cards
#  - For the Ascendant/Essence cycle, remove the mana costs and P/T values from
#    the bottom halves.
#  - Convert short set names to long set names
#  - Merge halves of split cards
#  - Convert rarities from single characters to full words
#  - Handle the duplicate printings entries for Invasion-block split cards
#  - Either this script or its successor needs to:
#   - Fix Homura's Essence
#   - Incorporate data/rarities.tsv (with affected rarities changed to the form
#     "Common (C1)"?)
#  - Remove italics from flavor text and watermarks

use strict;
use JSON::Syck;
use EnVec;
use EnVec::Util 'jsonify', 'joinRulings';

print "[\n";
$/ = '';
while (<>) {
 my($name, @entries) = split /\n/;
 my($content, $contentStr);
 my @printings;
 for (@entries) {
  my $entry = JSON::Syck::Load($_);
  ### Handle JSON-parsing errors
  my $multiverseid = delete $entry->{multiverseid};
  my $prnt;
  if (exists $entry->{part1}) {
   my $rulings1 = delete $entry->{part1}{rulings};
   $rulings1 = [ map { +{ date => $_->[0], ruling => $_->[1] } } @$rulings1 ]
    if defined $rulings1;
   my $rulings2 = delete $entry->{part2}{rulings};
   $rulings2 = [ map { +{ date => $_->[0], ruling => $_->[1] } } @$rulings2 ]
    if defined $rulings2;
   $entry->{rulings} = joinRulings $rulings1, $rulings2;
   $prnt = {};
   my $prnt1 = delete $entry->{part1}{prnt};
   my $prnt2 = delete $entry->{part2}{prnt};
   for my $field (qw<artist flavor watermark number multiverseid set rarity>) {
    my $val1 = $prnt1->{$field};
    my $val2 = $prnt2->{$field};
    next if !defined $val1 && !defined $val2;
    if (!defined $val1) {
     $prnt->{$field} = [ { subcard => 1, value => $val2 } ]
    } elsif (!defined $val2) {
     $prnt->{$field} = [ { subcard => 0, value => $val1 } ]
    } elsif ($val1 ne $val2) {
     $prnt->{$field} = [ { subcard => 0, value => $val1 },
			 { subcard => 1, value => $val2 } ]
    } else { $prnt->{$field} = $val1 }
   }
  } else {
   $entry->{rulings} = [ map { +{ date => $_->[0], ruling => $_[0] } }
			  @{$entry->{rulings}} ] if exists $entry->{rulings};
   $prnt = delete $entry->{prnt};
  }
  my $entryStr = jsonify $entry;
  if (!defined $content) { ($content, $contentStr) = ($entry, $entryStr) }
  elsif ($contentStr ne $entryStr) {
   print STDERR "$name/$multiverseid conflicts with initial content of $name\n"
  }
  push @printings, $prnt;
 }


}
print "\n]\n";

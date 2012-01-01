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
#  - Remove italics from flavor text?
#  - Remove italics from watermarks?

use strict;
use JSON::Syck;
use EnVec;
use EnVec::Util 'jsonify';

print "[\n";
$/ = '';
while (<>) {
 my($name, @entries) = split /\n/;
 my($content, $contentStr);
 my @printings;
 for (@entries) {
  my $entry = JSON::Syck::Load($_);
  # Handle JSON-parsing errors
  my $multiverseid = delete $entry->{multiverseid};
  my $prnt;
  if (exists $entry->{part1}) {
   $entry->{rulings} = mergeRulings delete $entry->{part1}{rulings},
    delete $entry->{part2}{rulings};
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
			  @{$entry->rulings} ] if exists $entry->{rulings};
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

sub mergeRulings($$) {
 my($rules1, $rules2) = @_;
 $rules1 = [] if !defined $rules1;
 $rules2 = [] if !defined $rules2;
 my @rulings;
 loop1: for my $r1 (@$rules1) {
  for my $i (0..$#$rules2) {
   if ($r1->[0] eq $rules2->[$i][0] && $r1->[1] eq $rules2->[$i][1]) {
    push @rulings, { date => $r1->[0], ruling => $r1->[1] };
    splice @$rules2, $i, 1;
    next loop1;
   }
  }
  push @rulings, { subcard => 0, date => $r1->[0], ruling => $r1->[1] };
 }
 return @rulings,
  map { +{ subcard => 1, date => $_->[0], ruling => $_->[1] } } @$rules2;
}

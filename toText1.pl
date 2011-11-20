#!/usr/bin/perl -w
use strict;
use EnVec qw< loadSets loadJSON >;

my $in;
if (@ARGV) { open $in, '<', $ARGV[0] or die "$0: $ARGV[0]: $!" }
else { $in = *STDIN }
loadSets;
my $cards = loadJSON $in;
print $_->toText1(0, 1), "\n" for @$cards;

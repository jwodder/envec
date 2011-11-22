#!/usr/bin/perl -w
use strict;
use EnVec qw< loadSets parseJSON >;

loadSets;
$/ = undef;
print $_->toText1(0, 1), "\n" for @{parseJSON <>};

#!/usr/bin/perl -w
use strict;
use EnVec 'loadSets';
use EnVec::Reader;

loadSets;
#print $_->toText1(0, 1), "\n" for @{loadJSON shift};
my $in = EnVec::Reader->open(shift);
print $_->toText1(0, 1), "\n" while <$in>;

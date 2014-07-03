#!/usr/bin/perl -w
use strict;
use EnVec 'loadSets', 'loadJSON';

loadSets;
print $_->toText1(0, 1), "\n" for @{loadJSON shift};

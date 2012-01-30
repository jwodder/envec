#!/usr/bin/perl -w
use strict;
use EnVec ('loadSets', 'loadJSON');

loadSets;
$/ = undef;
print $_->toText1(0, 1), "\n" for @{loadJSON shift};

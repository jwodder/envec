#!/usr/bin/perl -w
use strict;
use EnVec 'loadJSON';
print scalar @{loadJSON shift}, "\n";

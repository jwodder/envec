#!/usr/bin/perl -w
use strict;
use EnVec 'parseJSON';

$/ = undef;
print join("\t", map { defined $_ ? $_ : '' } $_->name, $_->type, $_->cost,
					      $_->indicator, $_->PT,
					      $_->loyalty, $_->HandLife), "\n"
 for map { $_->isSplit ? ($_->part1, $_->part2) : $_ } @{parseJSON <>};

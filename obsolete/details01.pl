#!/usr/bin/perl -w
use strict;
use Data::Dumper;
use LWP::Simple;
use EnVec 'detailsURL', 'parseDetails';

$Data::Dumper::Indent = 1;

for my $id (@ARGV) {
 my $details = get detailsURL $id;
 print STDERR "Could not fetch $id\n" and next if !defined $details;
 print Dumper({ parseDetails $details });
}

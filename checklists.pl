#!/usr/bin/perl -w
use strict;
use File::Temp;
use EnVec qw< loadSets allSets getChecklist loadChecklist >;

loadSets(shift || 'data/sets.tsv');
my $tmp = new File::Temp;
my $file = $tmp->filename;
for my $set (allSets) {
 print STDERR "Importing $set...\n";
 if (!getChecklist($set, $file)) {print STDERR "Could not fetch $set\n"; next; }
 my @cards = loadChecklist $file;
 for my $c (@cards) {
  print join("\t", map { $c->{$_} } qw< name multiverseid set number rarity
   color artist >), "\n"
 }
}

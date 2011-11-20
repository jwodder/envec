#!/usr/bin/perl -w
# Fetch the sets in which each card was first printed
use strict;
use File::Temp;
use EnVec qw< loadSets cmpSets setsToImport getChecklist loadChecklist >;

loadSets(shift || 'data/sets.tsv');
my %seen = ();
my $tmp = new File::Temp;
my $file = $tmp->filename;
for my $set (sort &cmpSets setsToImport) {
 if (!getChecklist($set, $file)) {print STDERR "Could not fetch $set\n"; next; }
 my @cards = loadChecklist $file;
 my $qty = 0;
 for my $c (@cards) {
  next if exists $seen{$c->{name}};
  print $c->{name}, "\t", $set, "\n";
  $seen{$c->{name}} = 1;
  $qty++;
 }
 print STDERR "$set introduced $qty cards.\n";
}

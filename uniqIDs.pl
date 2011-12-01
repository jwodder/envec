#!/usr/bin/perl -w
use strict;
use File::Temp;
use EnVec qw< loadSets setsToImport getChecklist loadChecklist >;

loadSets(shift || 'data/sets.tsv');
my %cardIDs = ();
my $tmp = new File::Temp;
my $file = $tmp->filename;
for my $set (setsToImport) {
 print STDERR "Importing $set...\n";
 print STDERR "Could not fetch $set\n" and next if !getChecklist($set, $file);
 for my $c (loadChecklist $file) {
  if (!exists $cardIDs{$c->{name}}) {
   $cardIDs{$c->{name}} = $c->{multiverseid};
   print $c->{name}, "\t", $c->{multiverseid}, "\n";
  }
 }
}
print STDERR scalar(keys %cardIDs), " cards imported\n";

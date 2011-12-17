#!/usr/bin/perl -w
use strict;
use EnVec qw< loadSets setsToImport checklistURL parseChecklist >;

loadSets(shift || 'data/sets.tsv');
my %cardIDs = ();
for my $set (setsToImport) {
 print STDERR "Importing $set...\n";
 my $list = get(checklistURL $set);
 print STDERR "Could not fetch $set\n" and next if !defined $list;
 for my $c (parseChecklist $list) {
  if (!exists $cardIDs{$c->{name}}) {
   $cardIDs{$c->{name}} = $c->{multiverseid};
   print $c->{name}, "\t", $c->{multiverseid}, "\n";
  }
 }
}
print STDERR scalar(keys %cardIDs), " cards imported\n";

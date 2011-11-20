#!/usr/bin/perl -w
use strict;
use EnVec qw< loadSets setsToImport getTextSpoiler loadTextSpoiler mergeCards
 dumpArray >;

loadSets(shift || 'data/sets.tsv');
-d 'oracle' or mkdir 'oracle' or die "$0: oracle/: $!";
my %cardHash;
for my $set (setsToImport) {
 (my $file = "oracle/$set.html") =~ tr/ "'/_/d;
 print STDERR "Checking for $set data...\n";
 if (!-e $file && !getTextSpoiler($set, $file)) {
  #print STDERR "Could not fetch set \"$set\": ", status_message($res), "\n";
  print STDERR "Could not fetch set \"$set\"\n";
  next;
 }
 print STDERR "Importing $set\n";
 my %imported = loadTextSpoiler($set, $file);
 print STDERR "$set imported (@{[scalar keys %imported]} cards)\n";
 mergeCards(%cardHash, %imported);
}
dumpArray values %cardHash;

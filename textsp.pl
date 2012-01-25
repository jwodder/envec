#!/usr/bin/perl -w
use strict;
use EnVec ':all';
use EnVec::Card::Util 'joinParts';

loadSets(shift || 'data/sets.tsv');
loadParts;
-d 'oracle' or mkdir 'oracle' or die "$0: oracle/: $!";

my %seen;
print "[\n";
for my $set (setsToImport) {
 (my $file = "oracle/$set.html") =~ tr/ "'/_/d;
 print STDERR "Checking for $set data...\n";
 if (!-e $file && !getTextSpoiler($set, $file)) {
  #print STDERR "Could not fetch set \"$set\": ", status_message($res), "\n";
  print STDERR "Could not fetch set \"$set\"\n";
  next;
 }
 print STDERR "Importing $set...\n";
 my %imported = loadTextSpoiler($set, $file);
 joinParts %imported;
 print STDERR "$set imported (@{[scalar keys %imported]} cards)\n";
 my $new = 0;
 for (sort keys %imported) {
  next if exists $seen{$_};
  print ",\n\n" if %seen;
  print $imported{$_}->toJSON;
  $seen{$_} = 1;
  $new++;
 }
 print STDERR "$new new cards added\n\n";
}
print "\n]\n";
print STDERR scalar(keys %seen), " cards imported\n";

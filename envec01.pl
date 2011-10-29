#!/usr/bin/perl -w
use strict;
use EnVec::Card;

my $setfile = 'sets.txt';

# Read list of long set names into @allSets; sets that aren't meant to be
# downloaded/imported should be commented out of the list of sets beforehand.
open my $sets, '<', $setfile or die "$0: $setfile: $!";
my @allSets = grep { !/^\s*#/ && !/^\s*$/ } <$sets>;
close $sets;
chomp for @allSets;

my %cardHash;

for my $set (@allSets) {
 (my $file = "oracle/$set.html") =~ tr/ /_/;
 getTextSpoiler($set, $file) or do {
  #print STDERR "Could not fetch set \"$set\": ", status_message($res), "\n";
  print STDERR "Could not fetch set \"$set\"\n";
  next;
 };
 my $qty = importTextSpoiler($set, $file);
 print STDERR "$set imported ($qty cards)\n";
}
print "[\n";
my $first = 1;
for (values %cardHash) {
 print ",\n\n" if !$first;
 print $_->toJSON;
 $first = 0;
}
print "]\n";

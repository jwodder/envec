#!/usr/bin/perl -w
use strict;
use EnVec qw< getTextSpoiler loadTextSpoiler mergeCards dumpArray >;

my $setfile = shift || 'sets.txt';

-d 'oracle' or mkdir 'oracle' or die "$0: oracle/: $!";

open my $sets, '<', $setfile or die "$0: $setfile: $!";
my @allSets = grep { !/^\s*#/ && !/^\s*$/ } <$sets>;
close $sets;

my %cardHash;
for my $set (@allSets) {
 chomp $set;
 (my $file = "oracle/$set.html") =~ tr/ "'/_/d;
 if (!-e $file && !getTextSpoiler($set, $file)) {
  #print STDERR "Could not fetch set \"$set\": ", status_message($res), "\n";
  print STDERR "Could not fetch set \"$set\"\n";
  next;
 }
 my %imported = loadTextSpoiler($set, $file);
 print STDERR "$set imported (@{[scalar keys %imported]} cards)\n";
 mergeCards(%cardHash, %imported);
}
dumpArray values %cardHash;

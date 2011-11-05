#!/usr/bin/perl -w
use strict;
use EnVec qw< getTextSpoiler loadTextSpoiler mergeCards dumpArray >;

-d 'oracle' or mkdir 'oracle' or die "$0: oracle/: $!";

my %cardHash;
for my $set (qw< Unglued Unhinged >) {
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

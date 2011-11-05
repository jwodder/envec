#!/usr/bin/perl -w
# The only data that this should lose by not merging should be most
# multiverseids, but who needs those?
use strict;
use EnVec qw< getTextSpoiler loadTextSpoiler >;

my $setfile = shift || 'sets.txt';

-d 'oracle' or mkdir 'oracle' or die "$0: oracle/: $!";

open my $sets, '<', $setfile or die "$0: $setfile: $!";
my @allSets = grep { !/^\s*#/ && !/^\s*$/ } <$sets>;
close $sets;

my %seen;
print "[\n";
for my $set (@allSets) {
 chomp $set;
 (my $file = "oracle/$set.html") =~ tr/ "'/_/d;
 if (!-e $file && !getTextSpoiler($set, $file)) {
  #print STDERR "Could not fetch set \"$set\": ", status_message($res), "\n";
  print STDERR "Could not fetch set \"$set\"\n";
  next;
 }
 print STDERR "Importing $set\n";
 my %imported = loadTextSpoiler($set, $file);
 print STDERR "$set imported (@{[scalar keys %imported]} cards)\n\n";
 for (sort keys %imported) {
  next if exists $seen{$_};
  print ",\n\n" if %seen;
  print $imported{$_}->toJSON;
  $seen{$_} = 1;
 }
}
print "\n]\n";
print STDERR scalar(keys %seen), " cards imported.\n";

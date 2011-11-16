#!/usr/bin/perl -w
# Fetch the sets in which each card was first printed
use strict;
use File::Temp;
use EnVec qw< getChecklist loadChecklist >;

my $setfile = shift || 'data/sets.tsv';
my $sets;
if ($setfile eq '-') { $sets = *STDIN }
else { open $sets, '<', $setfile or die "$0: $setfile: $!" }
my @allSets = ();
while (<$sets>) {
 next if /^\s*#/ || /^\s*$/;
 my(undef, undef, $name, $date, undef) = split /\t+/;
 $date =~ tr/0-9//cd;
 $date = 'zzzzz' if $date eq '';  # Promo set for Gatherer
 push @allSets, [ $name, $date ];
}
close $sets;

@allSets = map { $_->[0] } sort { $a->[1] cmp $b->[1] } @allSets;

my %seen = ();
my $tmp = new File::Temp;
my $file = $tmp->filename;
for my $set (@allSets) {
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

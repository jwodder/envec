#!/usr/bin/perl -w
use strict;
use File::Temp;
use LWP::Simple;
use EnVec ':all';
use EnVec::Util 'jsonify';

loadSets(shift || 'data/sets.tsv');
loadParts;

my %cardIDs = ();
{
 my $tmp = new File::Temp;
 my $file = $tmp->filename;
 for my $set (allSets) {
  print STDERR "Importing $set...\n";
  print STDERR "Could not fetch $set\n" and next if !getChecklist($set, $file);
  for my $c (loadChecklist $file) {
   $cardIDs{$c->{name}} = $c->{multiverseid} if !exists $cardIDs{$c->{name}}
  }
 }
 # Die, $tmp, die!
}

delete $cardIDs{$_} for flipBottoms, doubleBacks;

print STDERR "Fetching individual card data...\n\n";
for my $name (sort keys %cardIDs) {
 my @ids = ($cardIDs{$name});
 my %fetched = ();
 print $name, "\n";
 while (@ids) {
  my $id = shift @ids;
  print STDERR "$name/$id\n";
  my $details = get(isSplit $name ? detailsURL($id, $name) : detailsURL($id));
  print STDERR "Could not fetch $name/$id\n" and next if !defined $details;
  $fetched{$id} = 1;
  my %data = loadDetails $details;
  push @ids, grep { !exists $fetched{$_} } map { $_->[0] } (exists $data{part1} ? (@{$data{part1}{printings}}, @{$data{part2}{printings}}) : @{$data{printings}});
  print jsonify({idno => $id, %data}), "\n";
 }
 print STDERR "\n";
}

#!/usr/bin/perl -w
use strict;
use Getopt::Std;
use LWP::Simple;
use EnVec ':all';
use EnVec::Util 'jsonify';

my %opts;
getopts('C:S:o:l:', \%opts) || exit 2;
loadParts;

my $out;
if (!exists $opts{o} || $opts{o} eq '-') { $out = *STDOUT }
else { open $out, '>', $opts{o} or die "$0: $opts{o}: $!" }

my $log;
if (!exists $opts{l} || $opts{l} eq '-') { $log = *STDERR }
else { open $log, '>', $opts{l} or die "$0: $opts{l}: $!" }

my %cardIDs = ();
if (exists $opts{C}) {
 open my $in, '<', $opts{C} or die "$0: $opts{C}: $!";
 while (<$in>) {
  chomp;
  next if /^\s*#/ || /^\s*$/;
  my($card, $id) = split /\t+/;
  $cardIDs{$card} = $id if !exists $cardIDs{$card};
 }
 close $in;
} else {
 loadSets($opts{S} || 'data/sets.tsv');
 for my $set (setsToImport) {
  print $log "Importing $set...\n";
  my $list = get(checklistURL $set);
  print STDERR "Could not fetch $set\n" and next if !defined $list;
  for my $c (parseChecklist $list) {
   $cardIDs{$c->{name}} = $c->{multiverseid} if !exists $cardIDs{$c->{name}}
  }
 }
}

print $log scalar(keys %cardIDs), " cards imported\n\n";

delete $cardIDs{$_} for flipBottoms, doubleBacks;

print $log "Fetching individual card data...\n\n";
for my $name (sort keys %cardIDs) {
 my @ids = ($cardIDs{$name});
 my %seen = ($cardIDs{$name} => 1);
 print $out $name, "\n";
 while (@ids) {
  my $id = shift @ids;
  print $log "$name/$id\n";
  my $details = get(isSplit $name ? detailsURL($id, $name) : detailsURL($id));
  print STDERR "Could not fetch $name/$id\n" and next if !defined $details;
  my $card = parseDetails $details;
  for (map { $_->multiverseid->all } @{$card->printings}) {
   push @ids, $_ and $seen{$_} = 1 if !$seen{$_}
  }

  print $out jsonify({multiverseid => $id, $card->???}), "\n";  #####

 }
 print $out "\n";
}

#!/usr/bin/perl -w
use strict;
use Getopt::Std;
use LWP::Simple;
use EnVec ':all';
use EnVec::Util 'jsonify';
use EnVec::Card::Util 'joinCards';

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

print $log "Fetching individual card data...\n";
print $out "[\n";
my %split = ();
my $first = 1;

for my $name (sort keys %cardIDs) {
 if (!isSplit $name) {
  if ($first) { $first = 0 }
  else { print $out ",\n\n" }
 }
 my @ids = ($cardIDs{$name});
 my %seen = ($cardIDs{$name} => 1);
 my $card = undef;
 my @printings = ();
 while (@ids) {
  my $id = shift @ids;
  print $log "$name/$id\n";
  my $details = get(isSplit $name ? detailsURL($id, $name) : detailsURL($id));
  print STDERR "Could not fetch $name/$id\n" and next if !defined $details;
  my $prnt = parseDetails $details;
  if (!defined $card) { $card = $prnt }
  ### else { ensure $card == $prnt } ???
  for (map { $_->multiverseid->all } @{$prnt->printings}) {
   push @ids, $_ and $seen{$_} = 1 if !$seen{$_}
  }
  # Assume that the printing currently being fetched is the only one that has
  # an "artist" field.
  push @printings, grep { $_->artist->any } @{$prnt->printings};
 }
 $card->printings(\@printings);  ### Shouldn't these be sorted?
 if (isSplit $name) { $split{$name} = $card }
 else { print $out $card->toJSON }
}

print $log "Joining split cards...\n";
for my $left (splitLefts) {  # splitLefts is already sorted.
 my $right = ...

 if (!exists $split{$left} || !exists $split{$right}) {
  print STDERR ...
   if exists $split{$left} || exists $split{$right};
  next;
 }
 if ($first) { $first = 0 }
 else { print $out ",\n\n" }
 my $card = joinCards SPLIT_CARD, $left, $right;
 print $out $card->toJSON;
}

print $out "\n]\n";

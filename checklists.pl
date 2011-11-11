#!/usr/bin/perl -w
use strict;
use File::Temp;
use EnVec qw< getChecklist loadChecklist >;

my $setfile = shift || 'data/sets.txt';
my $sets;
if ($setfile eq '-') { $sets = *STDIN }
else { open $sets, '<', $setfile or die "$0: $setfile: $!" }
my @allSets = grep { !/^\s*#/ && !/^\s*$/ } <$sets>;
close $sets;

my $tmp = new File::Temp;
my $file = $tmp->filename;
for my $set (@allSets) {
 chomp $set;
 print STDERR "Importing $set...\n";
 if (!getChecklist($set, $file)) {print STDERR "Could not fetch $set\n"; next; }
 my @cards = loadChecklist $file;
 for my $c (@cards) {
  print join("\t", map { $c->{$_} } qw< name multiverseid set number rarity
   color artist >), "\n"
 }
}

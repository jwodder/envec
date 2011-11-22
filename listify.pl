#!/usr/bin/perl -w
use strict;

my $statFile = 'out/stats.txt';
my $checkFile = 'out/checks.txt';
my $flipFile = 'data/flip.txt';
my $doubleFile = 'data/double.txt';
my $tokenFile = 'data/tokens.txt';

my %cards = ();
open my $stats, '<', $statFile or die "$0: $statFile: $!";
while (<$stats>) {
 chomp;
 my($name, $type, $cost, $indic, $pt, $loyalty, $vanguard) = split /\t/;
 my $name2 = $name;
 if ($name2 =~ s: // (.+)$::) {
  $cards{$1} = 0;
  $type =~ s: //.*$::;
 }
 $cards{$name2} = [ $name, $cost, $type, $indic, $pt || $loyalty || $vanguard ];
}
close $stats;

for my $file ($flipFile, $doubleFile) {
 open my $in, '<', $file or die "$0: $file: $!";
 while (<$in>) {
  chomp;
  next if /^\s*#/ || /^\s*$/;
  my($a, $b) = split /\t+/;
  if (exists $cards{$b}) {
   $cards{$a}[4] = sprintf '%-5s  %-30s  %4$-30s %5$-5s %6$s', $cards{$a}[4],
    @{$cards{$b}}
  } else { $cards{$a}[4] = sprintf '%-5s  %-30s  ???', $cards{$a}[4], $b }
  # Stupid munged flip cards...
  $cards{$b} = 0;
 }
 close $in;
}

open my $tokens, '<', $tokenFile or die "$0: $tokenFile: $!";
while (<$tokens>) {
 chomp;
 next if /^\s*$/ || /^\s*#/;
 die "$_ is both a card and a token‽\n" if exists $cards{$_};
 $cards{$_} = 0;
}
close $tokens;

my @setList = ();
my $setName = undef;
open my $checks, '<', $checkFile or die "$0: $checkFile: $!";
while (<$checks>) {
 chomp;
 my($name, undef, $set, $num, $rarity, undef, undef) = split /\t/;
 print STDERR "$name: no such card\n" and next if !exists $cards{$name};
 next if !$cards{$name};
 if (!defined $setName) {$setName = $set; print "$set:\n"; }
 elsif ($setName ne $set) {
  print "$_\n" for uniq(sort @setList);
  print "\n$set:\n";
  @setList = ();
  $setName = $set;
 }
 my($name0, $cost, $type, $indic, $extra) = @{$cards{$name}};
 push @setList, sprintf('%3s  %-33s  %1s  %-40s  %-32s %-5s %s', $num, $name0,
  $rarity, $type, $cost, $indic, $extra);
}
close $checks;
print "$_\n" for uniq(sort @setList);

sub uniq {  # The list must be pre-sorted
 my $prev = undef;
 grep { (!defined $prev or $prev ne $_) and ($prev = $_ or 1) } @_;
}

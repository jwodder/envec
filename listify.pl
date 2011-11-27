#!/usr/bin/perl -w
use strict;
use open ':encoding(UTF-8)', ':std';
 # Using -CSD on the #! line doesn't work when invoking the script as "perl
 # script.pl", so the 'open' pragma is used here instead.

my $statFile   = 'out/stats.txt';
my $checkFile  = 'out/checks.txt';

my $splitFile  = 'data/split.tsv';
my $flipFile   = 'data/flip.tsv';
my $doubleFile = 'data/double.tsv';

my $tokenFile  = 'data/tokens.txt';

my %cards = ();
open my $stats, '<', $statFile or die "$0: $statFile: $!";
while (<$stats>) {
 chomp;
 my($name, $type, $cost, $indic, $pt, $loyalty, $vanguard) = split /\t/;
 $cost = '--' if !$cost;
 $cost .= " [$indic]" if $indic;
 $cards{$name} = [ $name, $cost, $type, $pt || $loyalty || $vanguard ];
}
close $stats;

for my $file ($splitFile, $flipFile, $doubleFile) {
 open my $in, '<', $file or die "$0: $file: $!";
 while (<$in>) {
  chomp;
  next if /^\s*#/ || /^\s*$/;
  my($a, $b) = split /\t+/;
  if (exists $cards{$b}) {
   push @{$cards{$a}}, $cards{$b};
   $cards{$b} = 0;
  }
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

my %rarities = (C => 'Common', U => 'Uncommon', R => 'Rare', M => 'Mythic',
 L => 'Land', S => 'Special');

my $setName = undef;
my @setList = ();
my($nameL, $typeL, $costL, $extraL) = (0, 0, 0, 0);
open my $checks, '<', $checkFile or die "$0: $checkFile: $!";
while (<$checks>) {
 chomp;
 my($name, undef, $set, $num, $rarity, undef, undef) = split /\t/;
 print STDERR "$name: no such card\n" and next if !exists $cards{$name};
 next if !$cards{$name};
 $rarity = $rarities{$rarity} if exists $rarities{$rarity};
 if (!defined $setName) { $setName = $set }
 elsif ($setName ne $set) {
  showSet($setName, @setList);
  $setName = $set;
  @setList = ();
  ($nameL, $typeL, $costL, $extraL) = (0, 0, 0, 0);
 }
 $num .= '.' if $num ne '';
 push @setList, [ $num, $rarity, @{$cards{$name}} ];
 $nameL = maxLen($nameL, $cards{$name}, 0);
 $costL = maxLen($costL, $cards{$name}, 1);
 $typeL = maxLen($typeL, $cards{$name}, 2);
 $extraL = maxLen($extraL, $cards{$name}, 3);
}
close $checks;
showSet($setName, @setList);

sub uniq {  # The list must be pre-sorted
 my $prev = undef;
 grep { (!defined $prev or $prev ne $_) and ($prev = $_ or 1) } @_;
}

sub maxLen {
 my($max, $arr, $i) = @_;
 $max = length $arr->[$i] if length $arr->[$i] > $max;
 $max = length $arr->[4][$i] if exists $arr->[4] && length $arr->[4][$i] > $max;
 return $max;
}

sub showCard {
 my($num, $rare, $name, $cost, $type, $extra, $alt) = @_;
 my $str = sprintf "%4s %-*s  %-*s  %-*s  %-*s  %s\n", $num, $nameL, $name,
  $typeL, $type, $extraL, $extra, $costL, $cost, $rare;
 if ($alt) {
  my($name2, $cost2, $type2, $extra2) = @$alt;
  $str .= sprintf "  // %-*s  %-*s  %-*s  %-*s\n", $nameL, $name2, $typeL,
   $type2, $extraL, $extra2, $costL, $cost2;
 }
 return $str;
}

sub showSet {
 my($set, @cards) = @_;
 print "$set:\n";
 if ($set eq 'Planechase' || $set eq 'Archenemy') {
  my(@special, @normal);
  for (@cards) {
   if ($_->[4] =~ /^(Plane|(Ongoing )?Scheme)\b/) { push @special, $_ }
   else { push @normal, $_ }
  }
  print for uniq(sort map { showCard(@$_) } @special);
  print "\n";
  print for uniq(sort map { showCard(@$_) } @normal);
 } else { print for uniq(sort map { showCard(@$_) } @cards) }
 print "\n";
}

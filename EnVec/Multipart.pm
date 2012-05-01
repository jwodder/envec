package EnVec::Multipart;
use warnings;
use strict;
use Carp;
use EnVec::Util 'openR';
use Exporter 'import';

our @EXPORT_OK = qw<
 NORMAL_CARD SPLIT_CARD FLIP_CARD DOUBLE_CARD
 loadedParts loadParts
 alternate
 isSplit  splits  splitLefts   splitRights
 isFlip   flips   flipTops     flipBottoms
 isDouble doubles doubleFronts doubleBacks
 classEnum
>;
# Functions used:
# - details.pl: flipBottoms, doubleBacks, isSplit, isFlip, isDouble, alternate
# - classEnum, loadParts, loadedParts
# - :const

our %EXPORT_TAGS = (
 all   => \@EXPORT_OK,
 const => [qw< NORMAL_CARD SPLIT_CARD FLIP_CARD DOUBLE_CARD >]
);

use constant {
 NORMAL_CARD => 1,
 SPLIT_CARD  => 2,
 FLIP_CARD   => 3,
 DOUBLE_CARD => 4
};

our $splitFile  = 'data/split.tsv';
our $flipFile   = 'data/flip.tsv';
our $doubleFile = 'data/double.tsv';

my(%split, %revSplit, %flip, %revFlip, %double, %revDoub);
my $loaded = 0;
my $warned = 0;

sub loadedParts() { $loaded }

sub loadParts(;%) {
 my %files = @_;
 # In case the loading croaks inside an eval while having previously loaded:
 (%split, %revSplit, %flip, %revFlip, %double, %revDoub) = ();
 $loaded = $warned = 0;
 %split = loadPartFile($files{split} || $splitFile);
 %revSplit = reverse %split;
 %flip = loadPartFile($files{flip} || $flipFile);
 %revFlip = reverse %flip;
 %double = loadPartFile($files{double} || $doubleFile);
 %revDoub = reverse %double;
 $loaded = 1;
}

sub loadPartFile {  # not for export
 my $file = shift;
 my $in = openR($file, 'EnVec::Multipart::loadParts');
 my %parts = ();
 while (<$in>) {
  chomp;
  next if /^\s*#/ || /^\s*$/;
  my($a, $b) = split /\t+/;
  $parts{$a} = $b;
 }
 close $in;
 return %parts;
}

sub loadCheck() {  # not for export
 if (!$loaded && !$warned) {
  carp "Warning: EnVec::Multipart::loadParts not yet invoked";
  $warned = 1;
 }
}

sub isSplit($) {
 loadCheck;
 return exists $split{$_[0]} ? 1 : exists $revSplit{$_[0]} ? 2 : '';
}

sub isFlip($) {
 loadCheck;
 return exists $flip{$_[0]} ? 1 : exists $revFlip{$_[0]} ? 2 : '';
}

sub isDouble($) {
 loadCheck;
 return exists $double{$_[0]} ? 1 : exists $revDoub{$_[0]} ? 2 : '';
}

sub splitLefts()   {loadCheck; return sort keys %split; }
sub splitRights()  {loadCheck; return sort keys %revSplit; }
sub flipTops()     {loadCheck; return sort keys %flip; }
sub flipBottoms()  {loadCheck; return sort keys %revFlip; }
sub doubleFronts() {loadCheck; return sort keys %double; }
sub doubleBacks()  {loadCheck; return sort keys %revDoub; }

sub splits()  {loadCheck; return %split; }
sub flips()   {loadCheck; return %flip; }
sub doubles() {loadCheck; return %double; }

sub alternate($) {
 my $side = shift;
 for (\%split, \%revSplit, \%flip, \%revFlip, \%double, \%revDoub) {
  return $_->{$side} if exists $_->{$side}
 }
 return undef;
}

sub classEnum($;$) {
 my($class, $default) = @_;
 return $default if !defined $class;
 if ($class =~ /^\d+$/) {
  for (NORMAL_CARD, SPLIT_CARD, FLIP_CARD, DOUBLE_CARD) {
   return $_ if $class == $_
  }
  return $default;
 } elsif ($class =~ /^normal(\b|_)/i) { return NORMAL_CARD }
 elsif ($class =~ /^split(\b|_)/i) { return SPLIT_CARD }
 elsif ($class =~ /^flip(\b|_)/i) { return FLIP_CARD }
 elsif ($class =~ /^double(\b|_)/i) { return DOUBLE_CARD }
 else { return $default }
}

1;

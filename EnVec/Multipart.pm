package EnVec::Multipart;
use warnings;
use strict;
use Carp;
use EnVec::Util 'openR';
use Exporter 'import';
our @EXPORT_OK = qw< NORMAL_CARD SPLIT_CARD FLIP_CARD DOUBLE_CARD classEnum
		     loadedParts loadParts
		     cardClass isPrimary isSecondary alternate
		     isSplit   splits  splitLefts   splitRights
		     isFlip    flips   flipTops     flipBottoms
		     isDouble  doubles doubleFronts doubleBacks >;
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

our $multiFile = 'data/multipart.tsv';

my %multipart;
my $loaded = 0;
my $warned = 0;

sub loadedParts() { $loaded }

sub loadParts(;$) {
 my $infile = shift || $multiFile;
 my $in = openR($infile, 'EnVec::Multipart::loadParts');
 %multipart = ();
 while (<$in>) {
  chomp;
  next if /^\s*#/ || /^\s*$/;
  my($a, $b, $enum) = split /\t+/;
  carp "EnVec::Multipart::loadParts: $infile: line $.: invalid/malformed entry"
   and next if !defined $enum;
  my $class = classEnum($enum, undef);
  if (!defined $class) {
   carp "EnVec::Multipart::loadParts: $infile: line $.: unknown card class \"$enum\"";
   next;
  } elsif ($class == NORMAL_CARD) { next }
  my $obj = { primary => $a, secondary => $b, cardClass => $class };
  for ($a, $b) {
   if (exists $multipart{$_}) {
    carp "EnVec::Multipart::loadParts: $infile: card name \"$_\" appears more than once"
   } else { $multipart{$_} = $obj }
  }
 }
 $loaded = 1;
 close $in;
}

sub loadCheck() {  # not for export
 if (!$loaded && !$warned) {
  carp "Warning: EnVec::Multipart::loadParts not yet invoked";
  $warned = 1;
 }
}

sub cardClass($) {
 loadCheck;
 return exists $multipart{$_[0]} ? $multipart{$_[0]}{cardClass} : NORMAL_CARD;
}

sub isPrimary($) {
 loadCheck;
 return exists $multipart{$_[0]} ? $multipart{$_[0]}{primary} eq $_[0] : 1;
}

sub isSecondary($) {
 loadCheck;
 return exists $multipart{$_[0]} ? $multipart{$_[0]}{secondary} eq $_[0] : '';
}

sub isSplit($)  { cardClass $_[0] == SPLIT_CARD }
sub isFlip($)   { cardClass $_[0] == FLIP_CARD }
sub isDouble($) { cardClass $_[0] == DOUBLE_CARD }

sub multibits($$) {  # not for export
 loadCheck;
 my($class, $side) = @_;
 grep { $multipart{$_}{cardClass} == $class && $multipart{$_}{$side} eq $_ }
  sort keys %multipart;
}

sub splitLefts()   { multibits SPLIT_CARD,  'primary' }
sub splitRights()  { multibits SPLIT_CARD,  'secondary' }
sub flipTops()     { multibits FLIP_CARD,   'primary' }
sub flipBottoms()  { multibits FLIP_CARD,   'secondary' }
sub doubleFronts() { multibits DOUBLE_CARD, 'primary' }
sub doubleBacks()  { multibits DOUBLE_CARD, 'secondary' }

sub splits()  { map { $multipart{$_} } splitLefts }
sub flips()   { map { $multipart{$_} } flipTops }
sub doubles() { map { $multipart{$_} } doubleFronts }

sub alternate($) {
 loadCheck;
 my $side = shift;
 if (exists $multipart{$side}) {
  my $obj = $multipart{$side};
  return $obj->{$obj->{primary} eq $side ? 'secondary' : 'primary'};
 } else { return undef }
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

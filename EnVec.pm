package EnVec;
use warnings;
use strict;
use Carp;

#use EnVec::Card;
#use EnVec::Card::Split;
use EnVec::Checklist ':all';
use EnVec::Colors;
use EnVec::Get ':all';
use EnVec::JSON ':all';
use EnVec::Sets ':all';
use EnVec::TextSpoiler ':all';

use EnVec::Card::Util qw< joinCards unmungFlip insertCard >;

use Exporter 'import';
our @EXPORT_OK = (@{$EnVec::Checklist::EXPORT_TAGS{all}},
		  @EnVec::Colors::EXPORT,
		  @{$EnVec::Get::EXPORT_TAGS{all}},
		  @{$EnVec::JSON::EXPORT_TAGS{all}},
		  @{$EnVec::Sets::EXPORT_TAGS{all}},
		  @{$EnVec::TextSpoiler::EXPORT_TAGS{all}},
		  qw< mergeCards loadedParts loadParts mergeParts >);
our %EXPORT_TAGS = (all => [ @EXPORT_OK ]);

sub mergeCards(\%\%) {
 # The contents of $db2 are merged into $db1.  $db2 is left intact, $db1 is not.
 my($db1, $db2) = @_;
 for (keys %$db2) {
  if (exists $db1->{$_}) { $db1->{$_} = $db1->{$_}->merge($db2->{$_}) }
  else { $db1->{$_} = $db2->{$_} }
 }
}

our $splitFile = 'data/split.tsv';
our $flipFile = 'data/flip.tsv';
our $doubleFile = 'data/double.tsv';

my %split = ();
my %flip = ();
my %double = ();
my $loaded = 0;
my $warned = 0;

sub loadedParts() { $loaded }

sub loadParts(;%) {
 my %files = @_;
 %split = loadPartFile($files{split} || $splitFile);
 %flip = loadPartFile($files{flip} || $flipFile);
 %double = loadPartFile($files{double} || $doubleFile);
 $loaded = 1;
}

sub loadPartFile {  # not for export
 my $file = shift;
 open my $in, '<', $file or croak "EnVec::loadParts: $file: $!";
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

sub mergeParts(\%) {
 if (!$loaded && !$warned) {
  carp "Warning: EnVec::loadParts not yet invoked";
  $warned = 1;
 }
 my $cards = shift;
 my($a, $b);
 while (($a, $b) = each %split) {
  if (exists $cards->{$a} && exists $cards->{$b}) {
   insertCard(%$cards, joinCards 'split', $cards->{$a}, $cards->{$b});
   delete $cards->{$a};
   delete $cards->{$b};
  }
 }
 while (($a, $b) = each %flip) {
  if (exists $cards->{$a} && exists $cards->{$b}) {
   $cards->{$b}->cost(undef);
   $cards->{$a} = joinCards 'flip', $cards->{$a}, $cards->{$b};
   delete $cards->{$b};
  } elsif (exists $cards->{$a} && $cards->{$a}->text =~ /\n----\n/) {
   $cards->{$a} = unmungFlip($cards->{$a})
  }
 }
 while (($a, $b) = each %double) {
  if (exists $cards->{$a} && exists $cards->{$b}) {
   $cards->{$a} = joinCards 'double', $cards->{$a}, $cards->{$b};
   delete $cards->{$b};
  }
 }
 return $cards;
}

1;

# Class for properties of card printings that can vary between different
# subcards of a multipart (split, flip, double-faced) card

# Each Multival object is (a blessed reference to) a list of lists of strings
# in which the sublist at index 0 contains the card-wide values, the sublist at
# index 1 contains the values for subcard 0, index 2 is for subcard 1, etc.
# None of these lists should ever contain empty strings, references, or undef.

package EnVec::Card::Multival;
use warnings;
use strict;
use Carp;
use EnVec::Util 'jsonify';

sub new {
 my($class, $val) = @_;
 my $self;
 if (!defined $val || $val eq '') { $self = [] }
 elsif (!ref $val) { $self = [ [ $val ] ] }
 elsif (ref $val eq 'ARRAY') {
  $self = [];
  my $undef = 0;
  for my $elem (@$val) {
   if (!defined $elem || $elem eq '') { $undef++ }
   elsif (ref $elem eq 'ARRAY') {
    my @elems = ();
    for (@$elem) {
     if (ref) { carp "Elements of sublists may not be references" }
     elsif (defined && $_ ne '') { push @elems, $_ }
     else { carp "Elements of sublists must be nonempty strings" }
    }
    if (!@elems) { $undef++ }
    else {push @$self, [] x $undef, \@elems; $undef = 0; }
   } elsif (ref $elem) {
    carp "List elements must be strings, array references, or undef";
    $undef++;
   } else {push @$self, [] x $undef, $elem; $undef = 0; }
  }
 } elsif (ref $val eq 'EnVec::Card::Multival') { return $val->copy }
 else {
  carp "Multival constructors must be strings, array references, or undef";
  $self = [];
 }
 bless $self, ref $class || $class;
}

sub all { map { @$_ } @{$_[0]} }  # Returns all defined values in the Multival

sub any { !!@{$_[0]} }

sub get {
 my($self, $i) = @_;
 return () if !@$self;
 $i = -1 if !defined $i;
 $i++ if $i < 0;
 return 0 <= $i && $i < @$self ? @{$self->[$i]} : ();
}

sub copy {
 my $self = shift;
 return $self->new([ @$self ]);
}

sub asArray { [ @{$_[0]} ] }

sub toJSON { jsonify($_[0]->asArray) }

sub mapvals {
 my($self, $thunk) = @_;
 return $self->new([ map { [ map { $thunk->($_) } @$_ ] } @$self ]);
}

1;

#sub arrayGet(&$@) {
# my($merger, $subcard, @vals) = @_;
# if (!@vals) { undef }
# elsif (!defined $subcard) {
#  defined $vals[0] ? $vals[0]
#   : $merger->(map { defined ? ref ? @$_ : $_ : '' } @vals[1..$#vals])
# } elsif ($subcard < -1 || $subcard >= $#vals) { undef }
# else { $vals[$subcard+1] }
#}
#
#sub artist    { arrayGet { join ' // ', @_ } $_[1], @{$_[0]->{artist}} }
#sub watermark { arrayGet { join ' // ', @_ } $_[1], @{$_[0]->{watermark}} }
#sub flavor    { arrayGet { join "\n----\n", @_ } $_[1], @{$_[0]->{flavor}} }
#sub notes     { arrayGet { join "\n----\n", @_ } $_[1], @{$_[0]->{notes}} }
#
#sub number {
# arrayGet {
#  (my $num = (sort { $a <=> $b } grep !/^$/, @_)[0]) =~ s/[[:alpha:]]+$//;
#  return $num;
# } $_[1], @{$_[0]->{number}}
#}
#
#sub multiverseid {
# arrayGet { (sort { $a <=> $b } grep !/^$/, @_)[0] }
#  $_[1], @{$_[0]->{multiverseid}}
#}

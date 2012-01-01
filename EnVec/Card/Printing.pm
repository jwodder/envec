package EnVec::Card::Printing;
use warnings;
use strict;
use Carp;

# Fields:
#  - set - string (required)
#  - date - string or undef
#  - rarity - string or undef
#  - number - list of strings
#  - artist - list of strings
#  - flavor - list of strings
#  - watermark - list of strings
#  - multiverseid - list of strings
#  - notes - list of strings
# The list-of-string fields store the card-wide values at index 0, the values
# for subcard 0 at index 1, the values for subcard 1 at index 2, etc.  Each
# entry is a nonempty string, a list of one (two?) or more nonempty strings
# (ideally, only the multiverseids of split cards from the Invasion block
# should use this), or undef.  The code should ensure that these lists never
# have any trailing undefs.

sub new {
 my($class, %fields) = @_;
 my $self = {};
 croak "EnVec::Card::Printing->new: 'set' field must be a nonempty string"
  if !exists $fields{set} || $fields{set} eq '' || ref $fields{set};
 $self->{set} = $fields{set};

 if (!exists $fields{rarity} || $fields{rarity} eq '') {
  $self->{rarity} = undef
 } elsif (ref $fields{rarity}) {
  carp ...
  $self->{rarity} = undef;
 } else { $self->{rarity} = $fields{rarity} }

 if (!exists $fields{date} || $fields{date} eq '') {
  $self->{date} = undef
 } elsif (ref $fields{date}) {
  carp ...
  $self->{date} = undef;
 } else { $self->{date} = $fields{date} }

 for (qw< number artist flavor watermark multiverseid notes >) {
  if (!exists $fields{$_} || $fields{$_} eq '') { $self->{$_} = [] }
  elsif (!ref $fields{$_}) { $self->{$_} = [ $fields{$_} ] }
  elsif (ref $fields{$_} eq 'ARRAY') {
   $self->{$_} = [];
   my $undef = 0;
   for my $elem (@{$fields{$_}}) {
    if (!defined $elem || $elem eq '') { $undef++ }
    elsif (ref $elem eq 'ARRAY') {
     my @elems = ();
     for (@$elem) {
      if (ref) { carp ... }
      elsif (defined && $_ ne '') { push @elems, $_ }
      else { carp ... }
     }
     if (!@elems) { $undef++ }
     elsif (@elems == 1) { push @{$self->{$_}}, $elems[0] }
     else { push @{$self->{$_}}, \@elems }
    } elsif (ref $elem) {
     carp ...
     $undef++;
    } else {
     push @{$self->{$_}}, undef x $undef, $elem;
     $undef = 0;
    }
   }
  } else {
   carp ...
   $self->{$_} = [];
  }
 }

 bless $self, ref $class || $class;
}

sub set { $_[0]->{set} }
sub rarity { $_[0]->{rarity} }
sub date { $_[0]->{date} }

sub arrayGet(&$@) {
 my($merger, $subcard, @vals) = @_;
 if (!@vals) { undef }
 elsif (!defined $subcard) {
  defined $vals[0] ? $vals[0] : $merger->(grep defined, @vals)
 #defined $vals[0] ? $vals[0] : $merger->(map { defined ? $_ : '' } @vals[1..$#vals])
 } elsif ($subcard < -1 || $subcard >= $#vals) { undef }
 else { $vals[$subcard+1] }
}

sub number       { arrayGet { (shift =~ /(\d+)/)[0] } $_[1], @{$_[0]->{number}} }
sub artist       { arrayGet { join ', ', @_ } $_[1], @{$_[0]->{artist}} }
sub flavor       { arrayGet { join "\n----\n", @_ } $_[1], @{$_[0]->{flavor}} }
sub watermark    { arrayGet { join '/', @_ } $_[1], @{$_[0]->{watermark}} }
sub multiverseid { arrayGet { shift } $_[1], @{$_[0]->{multiverseid}} }
sub notes        { arrayGet { join "\n----\n", @_ } $_[1], @{$_[0]->{notes}} }

sub allNumbers    { map { ref ? @$_ : $_ } grep defined, @{$set->{number}} }
sub allArtists    { map { ref ? @$_ : $_ } grep defined, @{$set->{artist}} }
sub allFlavor     { map { ref ? @$_ : $_ } grep defined, @{$set->{flavor}} }
sub allWatermarks { map { ref ? @$_ : $_ } grep defined, @{$set->{watermark}} }
sub allIDs        { map { ref ? @$_ : $_ } grep defined, @{$set->{multiverseid}} }
sub allNotes      { map { ref ? @$_ : $_ } grep defined, @{$set->{notes}} }

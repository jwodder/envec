package EnVec::Card::Printing;
use warnings;
use strict;
use Carp;

# Fields:
#  - set - string (required)
#  - rarity - string or undef
#  - date - string or undef
#  - number - Multival
#  - artist - Multival
#  - flavor - Multival
#  - watermark - Multival
#  - multiverseid - Multival
#  - notes - Multival

my @multival = qw< number artist flavor watermark multiverseid notes >;

sub multival($) {  # internal function, not for outside use
 my $val = shift;
 if (ref $val eq 'EnVec::Card::Multival') { $val->copy }
 else { new EnVec::Card::Multival $val }
}

sub new {
 my($class, %fields) = @_;
 my $self = {};
 croak "EnVec::Card::Printing->new: 'set' field must be a nonempty string"
  if !defined $fields{set} || $fields{set} eq '' || ref $fields{set};
 $self->{set} = $fields{set};

 if (!defined $fields{rarity} || $fields{rarity} eq '') {
  $self->{rarity} = undef
 } elsif (ref $fields{rarity}) {
  carp "EnVec::Card::Printing->new: 'rarity' field may not be a reference";
  $self->{rarity} = undef;
 } else { $self->{rarity} = $fields{rarity} }

 if (!defined $fields{date} || $fields{date} eq '') { $self->{date} = undef }
 elsif (ref $fields{date}) {
  carp "EnVec::Card::Printing->new: 'date' field may not be a reference";
  $self->{date} = undef;
 } else { $self->{date} = $fields{date} }

 $self->{$_} = multival $fields{$_} for @multival;
 bless $self, ref $class || $class;
}

sub set {
 my $self = shift;
 if (@_) {
  my $new = shift;
  croak "EnVec::Card::Printing->set: field must be a nonempty string"
   if !defined $new || $new eq '' || ref $new;
  $self->{set} = $new;
 }
 return $self->{set};
}

sub rarity {
 my $self = shift;
 if (@_) {
  my $new = shift;
  if (!defined $new || $new eq '') { $self->{rarity} = undef }
  elsif (ref $new) {
   carp "EnVec::Card::Printing->rarity: field may not be a reference";
   $self->{rarity} = undef;
  } else { $self->{rarity} = $new }
 }
 return $self->{rarity};
}

sub date {
 my $self = shift;
 if (@_) {
  my $new = shift;
  if (!defined $new || $new eq '') { $self->{date} = undef }
  elsif (ref $new) {
   carp "EnVec::Card::Printing->date: field may not be a reference";
   $self->{date} = undef;
  } else { $self->{date} = $new }
 }
 return $self->{date};
}

for my $field (@multival) {
 eval <<EOT;
  sub $field {
   my \$self = shift;
   \$self->{$field} = multival shift if \@_;
   return \$self->{$field};
  }
EOT
}

sub copy {
 my $self = shift;
 return $self->new(%$self);
}

sub toJSON {
 my $self = shift;
 my $str = '{"set": ' . jsonify($self->{set});
 $str .= ', "date": ' . jsonify($self->{date}) if defined $self->{date};
 $str .= ', "rarity": ' . jsonify($self->{rarity}) if defined $self->{rarity};
 for (@multival) {
  $str .= ", \"$_\": " . $self->{$_}->toJSON if $self->{$_}->any
 }
 return $str . '}';
}

1;

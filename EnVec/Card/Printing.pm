package EnVec::Card::Printing;
use warnings;
use strict;
use Carp;
use EnVec::Card::Multival;
use EnVec::Util;

# Fields:
#  - set - string (required)
#  - date - string or undef
#  - rarity - string or undef
#  - number - Multival
#  - artist - Multival
#  - flavor - Multival
#  - watermark - Multival
#  - multiverseid - Multival
#  - notes - Multival

my @multival = qw< number artist flavor watermark multiverseid notes >;

sub new {
 my($class, %fields) = @_;
 my $self = {};
 croak "EnVec::Card::Printing->new: 'set' field must be a nonempty string"
  if !defined $fields{set} || $fields{set} eq '' || ref $fields{set};
 $self->{set} = $fields{set};

 if (!defined $fields{date} || $fields{date} eq '') { $self->{date} = undef }
 elsif (ref $fields{date}) {
  carp "EnVec::Card::Printing->new: 'date' field may not be a reference";
  $self->{date} = undef;
 } else { $self->{date} = $fields{date} }

 if (!defined $fields{rarity} || $fields{rarity} eq '') {
  $self->{rarity} = undef
 } elsif (ref $fields{rarity}) {
  carp "EnVec::Card::Printing->new: 'rarity' field may not be a reference";
  $self->{rarity} = undef;
 } else { $self->{rarity} = $fields{rarity} }

 $self->{$_} = new EnVec::Card::Multival $fields{$_} for @multival;
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
   \$self->{$field} = new EnVec::Card::Multival shift if \@_;
   return \$self->{$field};
  }
EOT
}

sub copy {
 my $self = shift;
 #return $self->new(%$self);
 my %dup = (set    => $self->{set},
	    date   => $self->{date},
	    rarity => $self->{rarity});
 $dup{$_} = $self->{$_}->copy for @multival;
 bless \%dup, ref $self;
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

sub toXML {
 my $self = shift;
 my $str = "  <printing>\n   <set>" . txt2xml($self->{set}) . "</set>\n";
 $str .= "   <date>" . txt2xml($self->{date}) . "</date>\n"
  if defined $self->{date};
 $str .= "   <rarity>" . txt2xml($self->{rarity}) . "</rarity>\n"
  if defined $self->{rarity};
 $str .= $self->{$_}->toXML($_, $_ eq 'flavor' || $_ eq 'notes') for @multival;
 $str .= "  </printing>\n";
 return $str;
}

sub effectiveNum {
 my @nums = $_[0]->number->all;
 if (!@nums) { undef }
 elsif (@nums == 1) { $nums[0] }
 else { (sort { $a <=> $b } map {s/[a-z]+$//; $_; } @nums)[0] }
}

sub fromHashref {
 my($class, $hashref) = @_;
 return $hashref->copy if ref $hashref eq 'EnVec::Card::Printing';
 croak "EnVec::Card::Printing->fromHashref: argument must be a hash reference\n"
  if ref $hashref ne 'HASH';
 return $class->new(%$hashref);
}

1;

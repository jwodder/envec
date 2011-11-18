package EnVec::Card::Split;
use warnings;
use strict;
use Carp;
use Storable 'dclone';
use EnVec::Card;
use EnVec::Util;

our @ISA = ('EnVec::Card');

# Class::Struct forcibly resists being superclassed, so we have to do manually
# what it would automatically.

# Fields:
#  cardType - ideally one of the strings "split", "flip", or "double-faced"
#  part1 - an EnVec::Card
#  part2 - an EnVec::Card
#  printings - same as in EnVec::Card

sub new {
 my($class, %fields) = @_;
 my %self = (cardType => $fields{cardType}, part1 => undef, part2 => undef,
  printings => {});
 croak "new EnVec::Card::Split: cardType field may not be undef"
  if !defined $self{cardType};
 if (defined $fields{part1}) {
  croak "new EnVec::Card::Split: part1 field must be an EnVec::Card object"
   if !UNIVERSAL::isa($_[0], 'EnVec::Card');
  $self{part1} = $fields{part1};
 }
 if (defined $fields{part2}) {
  croak "new EnVec::Card::Split: part2 field must be an EnVec::Card object"
   if !UNIVERSAL::isa($_[0], 'EnVec::Card');
  $self{part2} = $fields{part2};
 }
 if (defined $fields{printings}) {
  croak "new EnVec::Card::Split: printings field must be a hash reference"
   if ref $fields{printings} ne 'HASH';
  $self{printings} = $fields{printings};
 }
 bless \%self, $class;
}

sub cardType {
 my $self = shift;
 if (@_) {
  croak "EnVec::Card::Split->cardType: field may not be sent to undef"
   if !defined $_[0];
  $self->{cardType} = shift;
 }
 return $self->{cardType};
}

sub part1 {
 my $self = shift;
 if (@_) {
  croak "EnVec::Card::Split->part1: field must be an EnVec::Card object"
   if !UNIVERSAL::isa($_[0], 'EnVec::Card');
  $self->{part1} = shift;
 }
 return $self->{part1};
}

sub part2 {
 my $self = shift;
 if (@_) {
  croak "EnVec::Card::Split->part2: field must be an EnVec::Card object"
   if !UNIVERSAL::isa($_[0], 'EnVec::Card');
  $self->{part2} = shift;
 }
 return $self->{part2};
}

sub printings {
 my $self = shift;
 if (@_) {
  if (ref $_[0] eq 'HASH') { $self->{printings} = shift }
  else {
   my $key = shift;
   $self->{printings}{$key} = shift if @_;
   return $self->{printings}{$key};
  }
 }
 return $self->{printings};
}

my $sep = ' // ';

for my $field (qw< name pow tough text loyalty handMod lifeMod color type >) {
 eval <<EOT;
sub $field {
 my \$self = shift;
 croak "Card fields of EnVec::Card::Split objects cannot be modified" if \@_;
 my \$left = \$self->part1->$field;
 my \$right = \$self->part2->$field;
 return undef if !defined \$left && !defined \$right;
 \$left = '' if !defined \$left;
 \$right = '' if !defined \$right;
 return \$left . \$sep . \$right;
}
EOT
}

for my $field (qw< supertypes types subtypes >) {
eval <<EOT;
sub $field {
 my \$self = shift;
 croak "Card fields of EnVec::Card::Split objects cannot be modified" if \@_;
 return [ \@{\$self->part1->$field}, \@{\$self->part2->$field} ];
}
EOT
}

sub cost {
 my $self = shift;
 croak "Card fields of EnVec::Card::Split objects cannot be modified" if @_;
 if ($self->cardType eq 'split') {
  ($self->part1->cost || '') . $sep . ($self->part2->cost || '')
 } else { $self->part1->cost }
}

sub toJSON {
 my $self = shift;
 my $str = " {\n  \"cardType\": @{[jsonify($self->cardType)]},\n  \"part1\": ";
 (my $sub = $self->part1->toJSON) =~ s/^/ /gm;
 $str .= $sub . ",\n  \"part2\": ";
 ($sub = $self->part2->toJSON) =~ s/^/ /gm;
 $str .= $sub . ",\n  \"printings\": " . jsonify($self->printings) . "\n }";
 return $str;
}

sub mergeCheck {  # Neither argument is modified.
 my($self, $other) = @_;
 croak 'Attempting to merge "', $self->name, '" with "', $other->name, '"'
  if $self->name ne $other->name;
 croak 'Attempting to merge multipart card "', $self->name,
  '" with a non-multipart version.' if !$other->isSplit;
 carp "Differing cardType values for ", $self->name, ': ', $self->cardType,
  ' vs. ', $other->cardType if $self->cardType ne $other->cardType;
 my $part1 = $self->part1->mergeCheck($other->part1);
 my $part2 = $self->part2->mergeCheck($other->part2);
 my $prints = mergePrintings $self->name, $self->printings, $other->printings;
 return new EnVec::Card::Split cardType => $self->cardType, part1 => $part1,
  part2 => $part2, printings => $prints;
}

our $tagwidth = $EnVec::Util::tagwidth;

sub showField {
 my($self, $field, $width) = @_;
 $width = ($width || 79) - $tagwidth - 1;
 if (!defined $field) { return '' }
 elsif ($field eq 'cardType') {
  return sprintf "%-${tagwidth}s %s\n", 'Format:', ucfirst $self->cardType
 } elsif ($field eq 'sets') { return showSets $self->printings, $width }
 else {
  my $subwidth = int(($width - length($sep)) / 2) + $tagwidth + 1;
  my $left = $self->part1->showField($field, $subwidth);
  my $right = $self->part2->showField($field, $subwidth);
  return '' if $left eq '' && $right eq '';
  my @leftLines = map { sprintf "%-${subwidth}s", $_ } split /\n/, $left;
  my @rightLines = map { substr $_, $tagwidth+1 } split /\n/, $right;
  if (@leftLines < @rightLines) {
   push @leftLines, (sprintf "%-${subwidth}s", '') x (@rightLines - @leftLines)
  } else { push @rightLines, ('') x (@leftLines - @rightLines) }
  return join '', map { $leftLines[$_] . $sep . $rightLines[$_] . "\n" }
   0..$#leftLines;
 }
}

sub isSplit { 1 }

sub copy {
 my $self = shift;
 # It isn't clear whether Storable::dclone can handle blessed objects, so...
 new EnVec::Card::Split
  cardType => $self->cardType,
  part1 => $self->part1->copy,
  part2 => $self->part2->copy,
  printings => dclone $self->printings;
}

1;

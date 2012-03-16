package EnVec::Card;
use warnings;
use strict;
use Carp;
use JSON::Syck;
use Storable 'dclone';
use EnVec::Card::Content;
use EnVec::Card::Printing;
use EnVec::Colors;
use EnVec::Sets;
use EnVec::Multipart ':const', 'classEnum';
use EnVec::Util;

use Class::Struct cardClass => '$', content => '@', printings => '@',
 rulings => '@';
# - Each element of the 'content' list is an EnVec::Card::Content object.
# - Each element of the 'printings' list is an EnVec::Card::Printing object.
# - Each element of the 'rulings' list is a hash with the following fields:
#  - date
#  - ruling
#  - subcard - 0 or 1 (optional)

my $sep = ' // ';

my %formats0 = (NORMAL_CARD, 'normal', SPLIT_CARD, 'split', FLIP_CARD, 'flip',
 DOUBLE_CARD, 'double-faced');

my %formats = (NORMAL_CARD, 'Normal card', SPLIT_CARD, 'Split card',
 FLIP_CARD, 'Flip card', DOUBLE_CARD, 'Double-faced card');

sub newCard {
 my($class, %attrs) = @_;
 my %content = ();
 for (qw< name cost text pow tough loyalty hand life indicator supertypes types
  subtypes >) { $content{$_} = $attrs{$_} if exists $attrs{$_} }
 return $class->fromHashref({ %attrs, content => [ \%content ] });
}

sub fromJSON {
 my($class, $str) = @_;
 my $hash = JSON::Syck::Load($str);
 croak "EnVec::Card->fromJSON: could not parse input\n" if !defined $hash;
 return $class->fromHashref($hash);
}

sub fromHashref {
 my($class, $hashref) = @_;
 return $hashref->copy if ref $hashref eq 'EnVec::Card';
 croak "EnVec::Card->fromHashref: argument must be a hash reference\n"
  if ref $hashref ne 'HASH';
 my %hash = %$hashref;
 $hash{cardClass} = classEnum($hash{cardClass}, NORMAL_CARD);
 if (ref $hash{content} eq 'ARRAY') {
  croak "EnVec::Card->fromHashref: 'content' field must be a nonempty array\n"
   if !@{$hash{content}};
  $hash{content} = [ map { EnVec::Card::Content->fromHashref($_) }
			 @{$hash{content}} ];
 } else {
  $hash{content} = [ EnVec::Card::Content->fromHashref($hash{content}) ]
 }
 $hash{printings} = [] if !defined $hash{printings};
 croak "EnVec::Card->fromHashref: 'printings' field must be an array or undef\n"
  if ref $hash{printings} ne 'ARRAY';
 $hash{printings} = [ map { EnVec::Card::Printing->fromHashref($_) }
			  @{$hash{printings}} ];
 $hash{rulings} = [] if !defined $hash{rulings};
 croak "EnVec::Card->fromHashref: 'rulings' field must be an array or undef\n"
  if ref $hash{rulings} ne 'ARRAY';
 return $class->new(%hash);
}

sub toJSON {
 my $self = shift;
 return " {\n  \"cardClass\": \"" . $formats0{$self->cardClass} . "\",\n"
  . "  \"content\": ["
    . join(', ', map { $_->toJSON } @{$self->content})
  . "],\n"
  . "  \"printings\": [\n   "
    . join(",\n   ", map { $_->toJSON } @{$self->printings})
  . "\n  ],\n"
  . "  \"rulings\": ["
  . (@{$self->rulings} ? "\n   "
    . join(",\n   ", map { jsonify($_) } @{$self->rulings})
  . "\n  " : '') . "]\n"
  . " }";
}

sub toXML {
 my $self = shift;
 my $str = " <card cardClass=\"" . txt2attr($formats0{$self->cardClass})
  . "\">\n";
 $str .= $_->toXML for @{$self->content};
 $str .= $_->toXML for @{$self->printings};
 for my $rule (@{$self->rulings}) {
  $str .= '  <ruling date="' . txt2attr($rule->{date}) . '"';
  $str .= ' subcard="' . txt2attr($rule->{subcard}) . '"'
   if exists $rule->{subcard};
  $str .= '>' . txt2xml($rule->{ruling}) . "</ruling>\n";
 }
 $str .= " </card>\n";
 return $str;
}

sub color   { colors2colors join '', map { $_->color }   @{$_[0]->content} }
sub colorID { colors2colors join '', map { $_->colorID } @{$_[0]->content} }

sub cmc {
 my $self = shift;
 return $self->part1->cmc if $self->cardClass == FLIP_CARD;
 my $cmc = 0;
 $cmc += $_->cmc for @{$self->content};
 return $cmc;
}

sub parts       { scalar @{$_[0]->content} }
sub part1       { $_[0]->content(0) }
sub part2       { $_[0]->content(1) }
sub isMultipart { $_[0]->parts > 1 }
sub isNormal    { $_[0]->cardClass == NORMAL_CARD }
sub isSplit     { $_[0]->cardClass == SPLIT_CARD }
sub isFlip      { $_[0]->cardClass == FLIP_CARD }
sub isDouble    { $_[0]->cardClass == DOUBLE_CARD }

sub sets { uniq sort map { $_->set } @{$_[0]->printings} }

sub firstSet { EnVec::Sets::firstSet($_[0]->sets) }

sub inSet {
 my($self, $set) = @_;
 if (wantarray) { grep { $_->set eq $set } @{$self->printings} }
 else {
  for (@{$self->printings}) { return 1 if $_->set eq $set }
  return '';
 }
}

sub hasType {
 my($self, $type) = @_;
 $self->isType($type) || $self->isSubtype($type) || $self->isSupertype($type);
}

sub isNontraditional {
 my $self = shift;
 $self->isType('Vanguard') || $self->isType('Plane') || $self->isType('Scheme');
}

for my $field (qw< name text pow tough loyalty hand life indicator type PT
 HandLife >) {
 eval <<EOT;
  sub $field {
   my \$self = shift;
   carp "Card fields of EnVec::Card objects cannot be modified directly" if \@_;
   my \@fields = map { \$_->$field } \@{\$self->content};
   return undef if !grep defined, \@fields;
   return join \$sep, map { defined(\$_) ? \$_ : '' } \@fields;
  }
EOT
}

for my $field (qw< supertypes types subtypes >) {
 eval <<EOT;
  sub $field {
   my \$self = shift;
   carp "Card fields of EnVec::Card objects cannot be modified directly" if \@_;
   return [ map { \@{\$_->$field} } \@{\$self->content} ];
  }
EOT
}

sub cost {
 my $self = shift;
 carp "Card fields of EnVec::Card objects cannot be modified directly" if @_;
 if ($self->isSplit) { join $sep, map { $_->cost || '' } @{$self->content} }
 else { $self->part1->cost }
}

sub isSupertype {
 my($self, $type) = @_;
 for (@{$self->supertypes}) { return 1 if $_ eq $type }
 return '';
}

sub isType {
 my($self, $type) = @_;
 for (@{$self->types}) { return 1 if $_ eq $type }
 return '';
}

sub isSubtype {
 my($self, $type) = @_;
 for (@{$self->subtypes}) { return 1 if $_ eq $type }
 return '';
}

sub copy {
 my $self = shift;
 # It isn't clear whether Storable::dclone can handle blessed objects, so...
 new EnVec::Card cardClass  => $self->cardClass,
		 content    => [ map { $_->copy } @{$self->content} ],
		 printings  => [ map { $_->copy } @{$self->printings} ],
		 rulings    => dclone $self->rulings;
}

my %fields = (
 name       => 'Name:',
 cost       => 'Cost:',
 cmc        => 'CMC:',
 indicator  => 'Color:',
 supertypes => 'Super:',
 types      => 'Types:',
 subtypes   => 'Sub:',
 type       => 'Type:',
 text       => 'Text:',
 pow        => 'Power:',
 tough      => 'Tough:',
 loyalty    => 'Loyalty:',
 hand       => 'Hand:',
 life       => 'Life:',
 PT         => 'P/T:',
 HandLife   => 'H/L:',
#printings  => 'Printings:',
);

my %shortRares = (common => 'C', uncommon => 'U', rare => 'R', land => 'L',
 'mythic rare' => 'M');

our $tagwidth = 8;

sub showField1 {
 my($self, $field, $width) = @_;
 $width = ($width || 79) - $tagwidth - 1;
 my($tag, $text);
 if (!defined $field) { return '' }
 elsif ($field eq 'sets') {
  my $text = join ', ', uniq map {
   my $rare = $_->rarity || 'UNKNOWN';
   $_->set . ' (' . ($shortRares{lc $rare} || $rare) . ')';
  } sortPrintings @{$self->printings};
  my($first, @rest) = wrapLines $text, $width, 2;
  $first = '' if !defined $first;
  return join '', sprintf("%-*s %s\n", $tagwidth, 'Sets:', $first),
   map { (' ' x $tagwidth) . " $_\n" } @rest;
 } elsif ($field eq 'cardClass') {
  return sprintf "%-*s %s\n", $tagwidth, 'Format:', $formats{$self->cardClass}
   ### || $self->cardClass
 } elsif (exists $fields{$field}) {
  $width = int(($width - ($self->parts - 1) * length($sep)) / $self->parts);
  my @lines = map {
   my $val = $_->$field();
   $val = '' if !defined $val;
   $val = join ' ', @$val if ref $val eq 'ARRAY';
   $val =~ s/—/--/g;
   [ map { sprintf '%-*s', $width, $_ } wrapLines($val, $width, 2) ];
  } @{$self->content};
  my $text = '';
  for (my $i=0; ; $i++) {
   my @txt = map { $_->[$i] } @lines;
   last if !grep defined, @txt;
   my $line = join $sep, map { defined($_) ? $_ : ' ' x $width } @txt;
   $line =~ s/\s+$//;
   $text .= sprintf('%-*s', $tagwidth, $i ? '' : $fields{$field}) . " $line\n";
  }
  return $text;
 } else { return '' }
}

sub toText1 {
 my($self, $width, $sets) = @_;
 my $str = $self->showField1('name', $width);
 $str .= $self->showField1('type', $width);
 $str .= $self->showField1('cost', $width) if $self->cost;
 $str .= $self->showField1('indicator', $width) if defined $self->indicator;
 $str .= $self->showField1('text', $width) if $self->text;
 $str .= $self->showField1('PT', $width) if defined $self->pow;
 $str .= $self->showField1('loyalty', $width) if defined $self->loyalty;
 $str .= $self->showField1('HandLife', $width) if defined $self->hand;
 $str .= $self->showField1('cardClass', $width) if $self->isMultipart;
 $str .= $self->showField1('sets', $width) if $sets;
 return $str;
}

1;

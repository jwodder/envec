package EnVec::Card;
use warnings;
use strict;
use Carp;
use Storable 'dclone';
use EnVec::Card::Content;
use EnVec::Colors;
use EnVec::Util;
use EnVec::Sets ();

use constant {
 NORMAL_CARD => 1,
 SPLIT_CARD  => 2,
 FLIP_CARD   => 3,
 DOUBLE_CARD => 4
};

my $sep = ' // ';

use Class::Struct cardType => '$', content => '@', printings => '@',
 rulings => '@';

# Each element of the 'content' list is an EnVec::Card::Content object.

# Each element of the 'printings' list is a hash with the following fields:
#  - set
#  - rarity
#  - multiverseid
#  - artist
#  - number (optional)
#  - flavor (optional)
#  - watermark (optional)
#  - notes (optional)
# Each field can be either a scalar value or a list of subhashes with the
# fields "subcard" and "value".

# Each element of the 'rulings' list is a hash with the following fields:
#  - date
#  - ruling
#  - subcard - 0 or 1 (optional)

my @scalars = qw< name cost text pow tough loyalty handMod lifeMod indicator >;
my @lists = qw< supertypes types subtypes >;

sub toJSON {
 my $self = shift;
 my $str = " {\n";
 ### $str .= "  \"cardType\": " . ???
 $str .= "  \"content\": [" . join(",\n", map { $_->toJSON } @{$self->content}) . "],\n";
 $str .= "  \"printings\": [" . join(",\n", map { jsonify($_) } @{$self->printings}) . "],\n";
 $str .= "  \"rulings\": [" . join(",\n", map { jsonify($_) } @{$self->rulings}) . "]\n";
 $str .= " }";
 return $str;
}

sub color { colors2colors join '', map { $_->color } @{$_[0]->content} }

sub colorID { colors2colors join '', map { $_->colorID } @{$_[0]->content} }

sub cmc {
 my $self = shift;
 my $cmc = 0;
 $cmc += $_->cmc for @{$self->content};
 return $cmc;
}

sub parts { scalar @{$_[0]->content} }

sub part1 { $_[0]->content(0) }

sub part2 { $_[0]->content(1) }

sub merge {  # Neither argument is modified.
 my($self, $other) = @_;
 croak 'EnVec::Card::merge: ', $self->name, ': card data mismatch'
  if $self->cardType != $other->cardType
     || $self->parts != $other->parts
     || grep { !$self->content($_)->equals($other->content($_)) }
         (0 .. $self->parts-1);
 my $new = $self->copy;
 $new->printings(mergePrintings $self->name, $self->printings, $other->printings);
 return $new;
}

sub isMultipart { $_[0]->parts > 1 }
sub isSplit { $_[0]->cardType == SPLIT_CARD }
sub isFlip { $_[0]->cardType == FLIP_CARD }
sub isDouble { $_[0]->cardType == DOUBLE_CARD }

sub sets { uniq sort map { $_->{set} } @{$_[0]->printings} }

sub firstSet { EnVec::Sets::firstSet($_[0]->sets) }

sub hasType {
 my($self, $type) = @_;
 $self->isType($type) || $self->isSubtype($type) || $self->isSupertype($type);
}

sub isNontraditional {
 my $self = shift;
 $self->isType('Vanguard') || $self->isType('Plane') || $self->isType('Scheme');
}

for my $field (qw< name text pow tough loyalty handMod lifeMod indicator type
 PT HandLife >) {
 eval <<EOT;
  sub $field {
   my \$self = shift;
   carp "Card fields of EnVec::Card objects cannot be modified directly" if \@_;
   my \@fields = map { \$_->$field } \@{\$self->content};
   return undef if !grep defined, \@fields;
   return join \$sep, map { defined ? \$_ : '' } \@fields;
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
 new EnVec::Card cardType  => $self->cardType,
		 content   => [ map { $_->copy } @{$self->content} ],
		 printings => dclone $self->printings,
		 rulings   => dclone $self->rulings;
}





my %fields = (
 name       => 'Name:',
 cost       => 'Cost:',
 cmc        => 'CMC:',
 indicator  => 'Color:',
#indicator  => 'Indicator:',
 supertypes => 'Super:',
 types      => 'Types:',
 subtypes   => 'Sub:',
 type       => 'Type:',
 text       => 'Text:',
 pow        => 'Power:',
 tough      => 'Tough:',
 loyalty    => 'Loyalty:',
 handMod    => 'Hand:',
 lifeMod    => 'Life:',
#PT         => 'Pow/Tough:',
 PT         => 'P/T:',
#HandLife   => 'Hand/Life:',
 HandLife   => 'H/L:',
#printings  => 'Printings:',
);

our $tagwidth = $EnVec::Util::tagwidth;

sub showField {
 my($self, $field, $width) = @_;
 $width = ($width || 79) - $tagwidth - 1;
 my($tag, $text);
 if (!defined $field) { return '' }
 elsif ($field eq 'sets') { return showSets $self->printings, $width }
 elsif (exists $fields{$field}) {
  $tag = $fields{$field};
  $text = $self->$field();
  if (!defined $text) { $text = '' }
  elsif (ref $text eq 'ARRAY') { $text = join ' ', @$text }
  $text =~ s/—/--/g;
 } else { return '' }
 my($first, @rest) = wrapLines $text, $width, 2;
 $first = '' if !defined $first;
 return join '', sprintf("%-*s %s\n", $tagwidth, $tag, $first),
  map { (' ' x $tagwidth) . " $_\n" } @rest;
}

sub toText1 {
 my($self, $width, $sets) = @_;
 my $str = $self->showField('name', $width);
 $str .= $self->showField('type', $width);
 $str .= $self->showField('cost', $width) if $self->cost;
 $str .= $self->showField('indicator', $width) if defined $self->indicator;
 $str .= $self->showField('text', $width) if $self->text;
 $str .= $self->showField('PT', $width) if defined $self->pow;
 $str .= $self->showField('loyalty', $width) if defined $self->loyalty;
 $str .= $self->showField('HandLife', $width) if defined $self->handMod;
 $str .= $self->showField('cardType', $width) if $self->isMultipart;
 $str .= $self->showField('sets', $width) if $sets;
 return $str;
}

sub inSet {
 my($self, $set) = @_;
 return defined $self->printings($set) && %{$self->printings($set)};
}

sub rarity {
 my($self, $set) = @_;
 return ($self->printings($set) || {})->{rarity};
}

sub setIDs {
 my($self, $set) = @_;
 return @{($self->printings($set) || {})->{ids} || []};
}

sub addSetID {
 my($self, $set, $id) = @_;
 if (!defined $self->printings($set)) { $self->printings($set, {ids => [$id]}) }
 else {
  my @ids = @{$self->printings($set)->{ids} || []};
  my $i;
  for ($i=0; $i<@ids; $i++) {
   last   if $id lt $ids[$i];
   return if $id eq $ids[$i];
  }
  splice @ids, $i, 0, $id;
  $self->printings($set)->{ids} = \@ids;
 }
}

1;

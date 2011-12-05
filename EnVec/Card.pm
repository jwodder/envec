package EnVec::Card;
use warnings;
use strict;
use Carp;
use Storable 'dclone';
use EnVec::Colors;
use EnVec::Util;
use EnVec::Sets ();

use Class::Struct name       => '$',
		  cost       => '$',
		  supertypes => '@',
		  types      => '@',
		  subtypes   => '@',
		  text       => '$',
		  pow        => '$',
		  tough      => '$',
		  loyalty    => '$',
		  handMod    => '$',
		  lifeMod    => '$',
		  indicator  => '$',  # /^W?U?B?R?G?$/
		  printings  => '%';
 # The 'printings' field is a mapping from long set names to subhashes
 # containing the following fields (each optional):
 #  rarity - string
 #  ids - list of multiverseid values, ideally sorted and without duplicates

my @scalars = qw< name cost pow tough text loyalty handMod lifeMod indicator >;
my @lists = qw< supertypes types subtypes >;

sub toJSON {
 my $self = shift;
 return " {\n" . join(",\n", map {
   my $val = $self->$_();
   defined $val && $val ne '' && !(ref $val eq 'ARRAY' && !@$val)
    && !(ref $val eq 'HASH' && !%$val) ? "  \"$_\": @{[jsonify $val]}" : ();
  } @scalars, @lists, 'printings') . "\n }";
}

sub colorID {
 my $self = shift;
 my $name = $self->name;
 my $colors = colors2bits($self->cost) | colors2bits($self->indicator);
 my $text = $self->text || '';
 $colors |= COLOR_WHITE if $text =~ m:\{(./)?W(/.)?\}|^\Q$name\E is white\.$:m;
 $colors |= COLOR_BLUE  if $text =~ m:\{(./)?U(/.)?\}|^\Q$name\E is blue\.$:m;
 $colors |= COLOR_BLACK if $text =~ m:\{(./)?B(/.)?\}|^\Q$name\E is black\.$:m;
 $colors |= COLOR_RED   if $text =~ m:\{(./)?R(/.)?\}|^\Q$name\E is red\.$:m;
 $colors |= COLOR_GREEN if $text =~ m:\{(./)?G(/.)?\}|^\Q$name\E is green\.$:m;
 ### Reminder text has to be ignored somehow.
 ### Do basic land types contribute to color identity?
 ### Handle things like the printed text of Transguild Courier.
 return bits2colors $colors;
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

sub mergeHashes($$$$) {  # internal function; not for export
 my($name, $prefix, $left, $right) = @_;
 my %res = %$left;
 for (keys %$right) {
  next if !defined $right->{$_};
  if (!defined $res{$_}) { $res{$_} = $right->{$_} }
  elsif ($res{$_} ne $right->{$_}) {
   carp "Differing $prefix$_ values for $name: ", jsonify $res{$_}, ' vs. ',
    jsonify $right->{$_}
  }
 }
 return %res;
}

sub mergeCheck {  # Neither argument is modified.
 my($self, $other) = @_;
 croak 'Attempting to merge "', $self->name, '" with "', $other->name, '"'
  if $self->name ne $other->name;
 croak 'Attempting to merge non-multipart card "', $self->name,
  '" with a multipart version.' if $other->isSplit;
 my %main = mergeHashes $self->name, '', { map { $_ => $self->$_() } @scalars },
  { map { $_ => $other->$_() } @scalars };
 for (@lists) {
  my $left = jsonify $self->$_();
  my $right = jsonify $other->$_();
  carp "Differing $_ values for ", $self->name, ': ', $left, ' vs. ', $right
   if $left ne $right;
  $main{$_} = $self->$_();
 }
 my $prints = mergePrintings $self->name, $self->printings, $other->printings;
 return new EnVec::Card (%main, printings => $prints);
}

sub merge {  # Neither argument is modified.
 my($self, $other) = @_;
 croak 'Attempting to merge "', $self->name, '" with "', $other->name, '"'
  if $self->name ne $other->name;
 # This version only looks at the 'name' and 'printings' fields, and the values
 # of all other fields are taken from the invocant.  If you want fields in the
 # argument but not the invocant to be taken into consideration and/or for
 # differences in field values to be checked, use mergeCheck.
 my $new = $self->copy;
 $new->printings(mergePrintings $self->name, $self->printings, $other->printings);
 return $new;
}

sub cmc {
 my $self = shift;
 return 0 if !$self->cost;
 my $cmc = 0;
 for (split /(?=\{)/, $self->cost) {
  if (/(\d+)/) { $cmc += $1 }
  elsif (y/WUBRGSwubrgs//) { $cmc++ }  # This weeds out {X}, {Y}, etc.
 }
 return $cmc;
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
#$str .= $self->showField('handMod', $width) if defined $self->handMod;
#$str .= $self->showField('lifeMod', $width) if defined $self->lifeMod;
 $str .= $self->showField('HandLife', $width) if defined $self->handMod;
 $str .= $self->showField('cardType', $width) if $self->isSplit;
 $str .= $self->showField('sets', $width) if $sets;
 return $str;
}

sub type {
 my $self = shift;
 return join ' ', @{$self->supertypes}, @{$self->types},
  @{$self->subtypes} ? ('--', @{$self->subtypes}) : ();
}

sub isSplit { '' }

sub copy {
 my $self = shift;
 # It isn't clear whether Storable::dclone can handle blessed objects, so...
 my %fields = map { $_ => $self->$_() } @scalars;
 $fields{$_} = [ @{$self->$_()} ] for @lists;
 $fields{printings} = dclone $self->printings;
 new EnVec::Card %fields;
}

sub sets { keys %{$_[0]->printings} }

sub firstSet { EnVec::Sets::firstSet($_[0]->sets) }

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

sub PT {
 my $self = shift;
 return defined $self->pow ? $self->pow . '/' . $self->tough : undef;
}

sub HandLife {
 my $self = shift;
 return defined $self->handMod ? $self->handMod . '/' . $self->lifeMod : undef;
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

sub hasType {
 my($self, $type) = @_;
 $self->isType($type) || $self->isSubtype($type) || $self->isSupertype($type);
}

1;

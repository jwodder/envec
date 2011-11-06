package EnVec::Card;
use Carp;
use EnVec::Colors;
use EnVec::Util;

use Class::Struct
 name => '$',
 cost => '$',
 supertypes => '@',
 types => '@',
 subtypes => '@',
 pow  => '$',
 tough => '$',
 text => '$',
 loyalty => '$',
 handMod => '$',
 lifeMod => '$',
 color => '$',  # /^W?U?B?R?G?$/
  # ^^ color indicators on double-faced cards (or are there other uses?)
 ids => '%',  # hash from long set names to Oracle card IDs
 rarities => '%';  # hash from long set names to rarities

my @scalars = qw< name cost pow tough text loyalty handMod lifeMod color >;
my @lists = qw< supertypes types subtypes >;

sub toJSON {
 my $self = shift;
 return " {\n" .  join(",\n", map {
   my $val = $self->$_();
   defined $val && $val ne '' && !(ref $val eq 'ARRAY' && !@$val)
    && !(ref $val eq 'HASH' && !%$val) && "  \"$_\": @{[jsonify $val]}";
  } @scalars, @list, 'ids', 'rarities') . "\n }";
}

sub colorID {
 my $self = shift;
 my $name = $self->name;
 my $colors = colors2bits($self->cost) | colors2bits($self->color);
 $colors |= COLOR_WHITE if $self->text =~ m:\{(./)?W(/.)?\}|^\Q$name\E is white\.$:m;
 $colors |= COLOR_BLUE  if $self->text =~ m:\{(./)?U(/.)?\}|^\Q$name\E is blue\.$:m;
 $colors |= COLOR_BLACK if $self->text =~ m:\{(./)?B(/.)?\}|^\Q$name\E is black\.$:m;
 $colors |= COLOR_RED   if $self->text =~ m:\{(./)?R(/.)?\}|^\Q$name\E is red\.$:m;
 $colors |= COLOR_GREEN if $self->text =~ m:\{(./)?G(/.)?\}|^\Q$name\E is green\.$:m;
 ### Reminder text has to be ignored somehow.
 ### Do basic land types contribute to color identity?
 ### Handle things like the printed text of Transguild Courier.
 return bits2colors $colors;
}

sub addSetID {my($self, $set, $id) = @_; $self->ids($set, $id); }

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

sub mergeWith {  # Neither argument is modified.
 my($self, $other) = @_;
 if ($self->name ne $other->name) {
  carp 'Attempting to merge "', $self->name, '" with "', $other->name, '"';
  return undef;
 }
 my %main = mergeHashes $self->name, '', { map { $_ => $self->$_() } @scalars },
  { map { $_ => $other->$_() } @scalars };
 for (@lists) {
  my $left = jsonify $self->$_();
  my $right = jsonify $other->$_();
  carp "Differing $_ values for ", $self->name, ': ', $left, ' vs. ', $right
   if $left ne $right;
  $main{$_} = $self->$_();
 }
 my %ids = mergeHashes $self->name, 'setID:', $self->ids, $other->ids;
 my %rarities = mergeHashes $self->name, 'setRarities:', $self->rarities,
  $other->rarities;
 return new EnVec::Card (%main, ids => \%ids, rarities => \%rarities);
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

my %shortRares = (common => 'C', uncommon => 'U', rare => 'R', land => 'L',
 'mythic rare' => 'MR');

my %fields = (
 name => 'Name:',
 cost => 'Cost:',
 cmc => 'CMC:',
 color => 'Color:',
 supertypes => 'Supertypes:',
 types => 'Types:',
 subtypes => 'Subtypes:',
 type => 'Type:',
 text => 'Text:',
 pow  => 'Power:',
 tough => 'Tough:',
 loyalty => 'Loyalty:',
 handMod => 'Hand:',
 lifeMod => 'Life:',
);
 #ids => '%',
 #rarities => '%',

our $tagwidth = 9;  # 11?

sub showField {
 my($self, $field, $width) = @_;
 $width = ($width || 80) - $tagwidth - 1;
 my($tag, $text);
 if (!defined $field) { return '' }
 elsif ($field eq 'PT') {
  $tag = 'P/T:';
  $text = defined $self->pow ? $self->pow . '/' . $self->tough : '';
 } elsif ($field eq 'sets') {
  $tag = 'Sets:';
  $text = join ', ', map {
   my $rare = $self->rarities($_);
   "$_ (" . ($shortRares{lc $rare} || $rare) . ')';
  } sort keys %{$self->rarities};
 } elsif (exists $fields{$field}) {
  $tag = $fields{$field};
  $text = $self->$field();
  if (!defined $text) { $text = '' }
  elsif (ref $text eq 'ARRAY') { $text = join ' ', @$text }
 } else { return '' }
 my($first, @rest) = wrapLines $text, $width;
 return join '', sprintf("%-${tagwidth}s %s\n", $tag, $first),
  map { (' ' x $tagwidth) . " $_\n" } @rest;
}

sub toText1 {
 my($self, $sets) = @_;
 my $str = $self->showField('name');
 $str .= $self->showField('format') if $self->isSplit;
 $str .= $self->showField('type');
 $str .= $self->showField('cost') if $self->cost;
 $str .= $self->showField('color') if defined $self->color;
 $str .= $self->showField('text') if $self->text;
 $str .= $self->showField('PT') if defined $self->pow;
 $str .= $self->showField('loyalty') if defined $self->loyalty;
 $str .= $self->showField('handMod') if defined $self->handMod;
 $str .= $self->showField('lifeMod') if defined $self->lifeMod;
 $str .= $self->showField('sets') if $sets;
 return $str;
}

sub type {
 my $self = shift;
 return join ' ', @{$self->supertypes}, @{$self->types},
  @{$self->subtypes} ? ('--', @{$self->subtypes}) : ();
}

sub isSplit { '' }

1;

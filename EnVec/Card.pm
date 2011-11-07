package EnVec::Card;
use Carp;
use Storable 'dclone';
use EnVec::Colors;
use EnVec::Util;

use Class::Struct
 name => '$',
 cost => '$',
 supertypes => '@',
 types => '@',
 subtypes => '@',
 pow => '$',
 tough => '$',
 text => '$',
 loyalty => '$',
 handMod => '$',
 lifeMod => '$',
 color => '$',  # /^W?U?B?R?G?$/
 printings => '%';
  # The 'printings' field is a mapping from long set names to subhashes
  # containing the following fields (each optional):
  #  rarity - string
  #  ids - list of multiverseid values, ideally sorted and without duplicates

my @scalars = qw< name cost pow tough text loyalty handMod lifeMod color >;
my @lists = qw< supertypes types subtypes >;

sub toJSON {
 my $self = shift;
 return " {\n" .  join(",\n", map {
   my $val = $self->$_();
   defined $val && $val ne '' && !(ref $val eq 'ARRAY' && !@$val)
    && !(ref $val eq 'HASH' && !%$val) && "  \"$_\": @{[jsonify $val]}";
  } @scalars, @list, 'printings') . "\n }";
}

sub colorID {
 my $self = shift;
 my $name = $self->name;
 my $colors = colors2bits($self->cost) | colors2bits($self->color);
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
   break  if $id lt $ids[$i];
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
#printings => 'Printings:',
);

our $tagwidth = 11;

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
   my $rare = $self->printings($_)->{rarity} || 'XXX';
   "$_ (" . ($shortRares{lc $rare} || $rare) . ')';
  } sort keys %{$self->printings};
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

sub copy {
 my $self = shift;
 # It isn't clear whether Storable::dclone can handle blessed objects, so...
 my %fields = map { $_ => $self->$_() } @scalars;
 $fields{$_} = [ @{$self->$_()} ] for @lists;
 $fields{printings} = dclone $self->printings;
 new EnVec::Card %fields;
}

1;

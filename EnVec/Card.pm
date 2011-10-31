package EnVec::Card;
use Carp;
use EnVec::Colors;
use EnVec::Util;

use Class::Struct
 name => '$',
 cost => '$',
 type => '$',
 pow  => '$',
 tough => '$',
 text => '$',
 loyalty => '$',
 handMod => '$',
 lifeMod => '$',
 color => '$',
  # ^^ color indicators on double-faced cards (or are there other uses?)
 ids => '%',  # hash from long set names to Oracle card IDs
 rarities => '%';  # hash from long set names to rarities

my @scalars = qw< name cost type pow tough text loyalty handMod lifeMod color >;

sub toJSON {
 my $self = shift;
 my $str = '';
 $str .= " {\n";
 $str .= defined $self->$_() && $self->$_() ne ''
  && "  \"$_\": @{[jsonify $self->$_()]},\n" for @scalars;
 $str .= "  \"ids\": {";
 $str .= join ', ', map { jsonify($_) . ': ' . $self->ids($_) }
  sort keys %{$self->ids};
 $str .= "},\n";
 $str .= "  \"rarities\": {";
 $str .= join ', ', map { jsonify($_) . ': ' . jsonify($self->rarities($_)) }
  sort keys %{$self->rarities};
 $str .= "}\n }";
 return $str;
}

sub colorID {
 my $self = shift;
 my $name = $self->name;
 my $colors = colors2bits $self->manacost;
 $colors |= COLOR_WHITE if $self->text =~ /\{W\}|^\Q$name\E is white\.$/m;
 $colors |= COLOR_BLUE  if $self->text =~ /\{U\}|^\Q$name\E is blue\.$/m;
 $colors |= COLOR_BLACK if $self->text =~ /\{B\}|^\Q$name\E is black\.$/m;
 $colors |= COLOR_RED   if $self->text =~ /\{R\}|^\Q$name\E is red\.$/m;
 $colors |= COLOR_GREEN if $self->text =~ /\{G\}|^\Q$name\E is green\.$/m;
 ### TODO: Handle hybrid mana!
 ### TODO: Handle color indicators!
 return bits2colors $colors;
}

sub addSetID {
 my($self, $set, $id) = @_;
 $self->ids($set, $id);
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

sub mergeWith {  # Neither argument is modified.
 my($self, $other) = @_;
 if ($self->name ne $other->name) {
  carp 'Attempting to merge "', $self->name, '" with "', $other->name, '"';
  return;
 }
 my %main = mergeHashes $self->name, '', { map { $_ => $self->$_() } @scalars },
  { map { $_ => $other->$_() } @scalars };
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
 type => 'Type:',
 loyalty => 'Loyalty:',
 color => 'Color:',
 pow  => 'Power:',
 tough => 'Tough:',
 handMod => 'Hand:',
 lifeMod => 'Life:',
 # supertypes => 'Supertypes:',
 # types => 'Types:',
 # subtypes => 'Subtypes:',
);
 #ids => '%',
 #rarities => '%',

my $tagwidth = 9;  # 11?

sub longField($$$) {  # internal function; not for export
 my($tag, $width, $txt) = @_;
 my($first, @rest) = wrapLines $txt, $width;
 join '', sprintf("%-${tagwidth}s %s\n", $tag, $first),
  map { (' ' x $tagwidth) . " $_\n" } @rest;
}

sub showField {
 my($self, $field, $width) = @_;
 $width = ($width || 80) - $tagwidth - 1;
 return '' if !defined $field;
 if ($field eq 'PT') {
  sprintf "%-${tagwidth}s %s\n", 'P/T:',
   defined $self->pow ? $self->pow . '/' . $self->tough : ''
 } elsif ($field eq 'text') {
  (my $txt = $self->text || '') =~ s/\n/\n\n/g;
  longField 'Text:', $width, $txt;
 } elsif ($field eq 'sets') {
  longField 'Sets:', $width, join ', ', map {
   my $rare = $self->rarities($_);
   "$_ (" . ($shortRares{lc $rare} || $rare) . ')';
  } sort keys %{$self->rarities}
 } elsif (exists $fields{$field}) {
  my $dat = $self->$field();
  if (!defined $dat) { $dat = '' }
  elsif (ref $dat eq 'ARRAY') { $dat = join ' ', @$dat }
  sprintf "%-${tagwidth}s %s\n", $fields{$field}, $dat;
 } else { '' }
}

1;

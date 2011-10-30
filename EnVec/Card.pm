package EnVec::Card;
use Carp;
use EnVec::Colors;
use EnVec::Util 'jsonify';

use Class::Struct
 name => '$',
 cost => '$',
 type => '$',
 PT   => '$',
 text => '$',
 loyalty => '$',
 HandLife => '$',
 color => '$',
  # ^^ color indicators on double-faced cards (or are there other uses?)
 ids => '%',  # hash from long set names to Oracle card IDs
 rarities => '%';  # hash from long set names to rarities

my @scalars = qw< name cost type PT text loyalty HandLife color >;

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

1;

package EnVec::Card;

use EnVec::Colors;

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

sub toJSON {
 my $self = shift;
 my $str = '';
 $str .= " {\n";
 $str .= defined($self->$_()) && "  \"$_\": @{[jsonify $self->$_()]},\n"
  for qw< name cost type PT text loyalty HandLife color >;
 $str .= "  \"ids\": {\n";
 $str .= join ', ', map { jsonify($_) . ': ' . $self->ids($_) }
  sort keys %{$self->ids};
 $str .= "},\n";
 $str .= "  \"rarities\": {\n";
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

# sub addSetRarity

1;

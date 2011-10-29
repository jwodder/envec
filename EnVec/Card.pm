package EnVec::Card;

use EnVec::Colors;

use Class::Struct
 name => '$',
 cost => '$',
 type => '$',
 powtough => '$',
 text => '$',
 sets => '%';  # Hash from long set names to Oracle card IDs

sub toJSON {
 my $self = shift;
 my $str = '';
 $str .= " {\n";
 for (qw< name cost type powtough text >) {
  $str .= "  \"$_\": \"@{[jsonify $self->$_()]}\",\n" if defined $self->$_()
 }
 $str .= "  \"sets\": {\n";
 $str .= join ",\n", map { '   "' . jsonify($_) . '": ' . $self->sets($_) }
  keys %{$self->sets};
 $str .= "\n  }\n }";
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

1;

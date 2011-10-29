package EnVec::Card;

use Class::Struct
 name => '$',
 manacost => '$',
 cardtype => '$',
 powtough => '$',
 text => '$',
 colors => '$',
 sets => '%';  # Hash from long set names to Oracle card IDs

sub toJSON {
 my $self = shift;
 my $str = '';
 $str .= " {\n";
 for (qw< name manacost cardtype powtough text colors >) {
  $str .= "  \"$_\": \"@{[jsonify $self->$_()]}\",\n" if defined $self->$_()
 }
 $str .= "  \"sets\": {\n";
 $str .= join ",\n", map { '   "' . jsonify($_) . '": ' . $self->sets($_) }
  keys %{$self->sets};
 $str .= "\n  }\n }";
 return $str;
}

1;

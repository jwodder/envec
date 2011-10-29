package Card;

use Class::Struct
 name => '$',
 manacost => '$',
 cardtype => '$',
 powtough => '$',
 text => '$',
 colors => '$',
 sets => '%';  # Hash from long set names to Oracle card IDs

sub jsonify($) {
 my $str = shift;
 $str =~ s/([\\"])/\\$1/g;
 $str =~ s/[\n\r]/\\n/g;
 $str =~ s/\t/\\t/g;
 return $str;
}

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
 $str .= "\n  }\n }\n";
 return $str;
}

sub getMainCardType {
 my $result = $_[0]->getCardType;
 # Legendary Artifact Creature - Golem
 # Instant // Instant
 $result =~ s/-.*$//;  # How should this handle U+2014?
 $result =~ s://.*$::;
 # Legendary Artifact Creature
 # Instant
 my @words = split ' ', $result;
 return $words[$#words];
 # Creature
 # Instant
}

sub getCorrectedName {
 my $result = $_[0]->{name};
 # Fire // Ice, Circle of Protection: Red
 $result =~ s: // ::g;
 $result =~ y/://d;
 return $result;
}

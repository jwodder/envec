package CardInfo;

use Class::Struct
 name => '$',
 manacost => '$',
 cardtype => '$',
 powtough => '$',
 text => '$',
 colors => '$',
 sets => '%';  # Hash from long set names to Oracle card IDs

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

sub addToSet {  ## (CardSet *set)
 my($self, $set) = @_;
 $set->append($self);
 push @{$self->{sets}}, $set;
}

package EnVec::JSON;
use warnings;
use strict;
use JSON::Syck;
use EnVec::Card;
use Exporter 'import';
our @EXPORT_OK = qw< dumpArray dumpHash fromJSON parseJSON loadJSON >;
our %EXPORT_TAGS = (all => \@EXPORT_OK);

sub dumpArray(@) {
 ### TODO: Add an optional argument for dumping to a filehandle
 print "[\n";
 my $first = 1;
 for (@_) {print ",\n\n" if !$first; print $_->toJSON; $first = 0; }
 print "\n]\n";
}

sub dumpHash(%) {
 ### TODO: Add an optional argument for dumping to a filehandle
 ### Add an optional argument for turning on sorting?
 my %db = @_;
 print "{\n";
 my $first = 1;
 for (keys %db) {
  print ",\n\n" if !$first;
  print ' ', jsonify $_, ': ', $_->toJSON;
  $first = 0;
 }
 print "\n}\n";
}

sub parseJSON($) {  # load from a string
 my $data = JSON::Syck::Load(shift);
 if (ref $data eq 'ARRAY') { [ map { EnVec::Card->fromJSON($_) } @$data ] }
 elsif (ref $data eq 'HASH') {
  +{ map { $_ => EnVec::Card->fromJSON($data->{$_}) } keys %$data }
 }
}

# Load from a filehandle:
sub loadJSON($) {local $/ = undef; parseJSON readline shift; }

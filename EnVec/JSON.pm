package EnVec::JSON;
use warnings;
use strict;
use JSON::Syck;
use EnVec::Card;
use EnVec::Card::Split;

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

sub fromJSON($) {  # converts a single hash reference into a single Card object
 my $obj = shift;
 if (exists $obj->{cardType}) {
  # Stupid Perl complains that it can't check a prototype within the function
  # itself....
  $obj->{part1} = &fromJSON($obj->{part1});
  $obj->{part2} = &fromJSON($obj->{part2});
  return new EnVec::Card::Split %$obj;
 } else { return new EnVec::Card %$obj }
}

sub parseJSON($) {  # load from a string
 my $data = JSON::Syck::Load(shift);
 if (ref $data eq 'ARRAY') { [ map { fromJSON($_) } @$data ] }
 elsif (ref $data eq 'HASH') {
  +{ map { $_ => fromJSON($data->{$_}) } keys %$data }
 }
}

# Load from a filehandle:
sub loadJSON($) {local $/ = undef; my $in = shift; parseJSON <$in>; }
 # Doing "<$_[0]>" instead of "my $in = shift; ... <$in>" is wrong (see perlop).

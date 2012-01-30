package EnVec::JSON;
use warnings;
use strict;
use JSON::Syck;
use EnVec::Card;
use EnVec::Util 'jsonify';
use Exporter 'import';
our @EXPORT_OK = qw< dumpArray dumpHash parseJSON loadJSON >;
our %EXPORT_TAGS = (all => \@EXPORT_OK);

sub dumpArray(\@;$) {  # Should it be ($;$) instead?
 my $array = shift;
 my $fh = shift || select;
 print $fh "[\n";
 my $first = 1;
 for (@$array) {
  print $fh ",\n\n" if !$first;
  print $fh $_->toJSON;
  $first = 0;
 }
 print $fh "\n]\n";
}

sub dumpHash(\%;$$) {  # Should it be ($;$$) instead?
 my($hash, $sort, $fh) = @_;
 $fh ||= select;
 print $fh "{\n";
 my $first = 1;
 for ($sort ? sort keys %$hash : keys %$hash) {
  print $fh ",\n\n" if !$first;
  print $fh ' ', jsonify($_), ': ', $hash->{$_}->toJSON;
  $first = 0;
 }
 print $fh "\n}\n";
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

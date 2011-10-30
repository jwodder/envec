package EnVec::JSON;
use EnVec::Card;

use Exporter 'import';
our @EXPORT_OK = qw< dumpArray dumpHash loadJSON >;
our %EXPORT_TAGS = (all => [ @EXPORT_OK ]);

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

sub loadJSON($) {  # load from a filehandle
 my $inf = shift;
 local $/ = undef;
 my $data = JSON::Syck::Load(<$inf>);
 if (ref $data eq 'ARRAY') { [ map { new EnVec::Card %$_ } @$data ] }
 elsif (ref $data eq 'HASH') {
  +{ map { $_ => new EnVec::Card %{$data->{$_}} } keys %$data }
 }
}

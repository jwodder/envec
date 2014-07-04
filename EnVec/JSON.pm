package EnVec::JSON;
use warnings;
use strict;
use Carp;
use JSON::Syck;
use EnVec::Card;
use EnVec::Util 'jsonify', 'openR';
use Exporter 'import';
our @EXPORT_OK = qw< dumpArray parseJSON loadJSON >;
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

sub parseJSON($) {  # Load from a string
 my $data = JSON::Syck::Load(shift);
 croak "EnVec::JSON::parseJSON: could not parse input\n" if !defined $data;
 if (ref $data eq 'ARRAY') { [ map { EnVec::Card->fromHashref($_) } @$data ] }
 else { croak "EnVec::JSON::parseJSON: root structure must be an array" }
}

sub loadJSON(;$) {  # Load from a file (identified by name) or stdin
 my $file = shift;
 my $fh = openR($file, 'EnVec::JSON::loadJSON');
 local $/ = undef;
 return parseJSON <$fh>;
}

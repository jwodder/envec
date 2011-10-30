package EnVec::Util;

use JSON::Syck;
use XML::DOM::Lite qw< TEXT_NODE ELEMENT_NODE >;
use EnVec::Card;

use Exporter 'import';
our @EXPORT_OK = qw< simplify trim textContent jsonify addCard dumpArray
 dumpHash loadJSON >;

sub simplify($) {
 my $str = shift;
 $str =~ s/^\s+|\s+$//g;
 $str =~ s/\s+/ /g;
 return $str;
}

sub trim($) {
 my $str = shift;
 $str =~ s/^\s+|\s+$//g;
 return $str;
}

sub textContent($) {
# cf. <http://www.w3.org/TR/2004/REC-DOM-Level-3-Core-20040407/core.html#Node3-textContent>
 my $node = shift;
 if ($node->nodeType == TEXT_NODE) { $node->nodeValue }
 elsif ($node->nodeType == ELEMENT_NODE) {
  $node->nodeName eq 'br' ? "\n"
   : join('', map { textContent $_ } @{$node->childNodes})
 } ### else { ??? }
}

sub jsonify($) {
 my $str = shift;
 $str =~ s/([\\"])/\\$1/g;
 $str =~ s/[\n\r]/\\n/g;
 $str =~ s/\t/\\t/g;
 return '"' . $str . '"';
}

sub addCard(\%$$%) {
 my($db, $set, $id, %fields) = @_;
 my $splitCard = ($fields{name} =~ s/ \(.*\)//);
 my $card;
 if (exists $db->{$fields{name}}) {
  $card = $db->{$fields{name}};
  $card->text($card->text() . "\n---\n" . $fields{text})
   if $splitCard && index($card->text, $fields{text}) == -1;
 } else {
  $fields{name} =~ s/^XX//;  ## Workaround for card name weirdness
  $card = new EnVec::Card %fields;
  $db->{$fields{name}} = $card;
 }
 $card->addSetID($set, $id);
 return $card;
}

sub dumpArray(@) {
 ### TODO: Add an optional argument for dumping to a filehandle
 print "[\n";
 my $first = 1;
 for (@_) {print ",\n\n" if !$first; print $_->toJSON; $first = 0; }
 print "]\n";
}

sub dumpHash(%) {
 ### TODO: Add an optional argument for dumping to a filehandle
 my %db = @_;
 print "{\n";
 my $first = 1;
 for (keys %db) {
  print ",\n\n" if !$first;
  print ' ', jsonify $_, ': ', $_->toJSON;
  $first = 0;
 }
 print "}\n";
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

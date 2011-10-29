package EnVec::TextSpoiler;
use XML::DOM::Lite qw< Parser TEXT_NODE ELEMENT_NODE >;
use EnVec::Card;

sub textSpoiler($$) {
 my($set, $file) = @_;
 my %cards = ();

 ## Workaround for ampersand bug in text spoilers:
 #my $index = -1;
 #while (($index = index $data, '&', $index + 1) != -1) {
 # my $semicolonIndex = index $dat, ';', $index;
 # if ($semicolonIndex - $index > 5) {
 #  substr $data, $index + 1, 0, 'amp;';
 #  $index += 4;
 # }
 #}

 my $parser = Parser->new;
 my $doc = $parser->parseFile($file);
 ### TODO: Handle parse errors somehow!
 for my $div (@{$doc->getElementsByTagName('div')}) {
  my $divClass = $div->getAttribute('class');
  if (defined $divClass && $divClass eq 'textspoiler') {
   my($name, $cost, $type, $PT, $text);
   my $id = 0;
   for my $tr (@{$div->getElementsByTagName('tr')}) {
    my $tds = $tr->getElementsByTagName('td');
    if ($tds->length != 2) {
     $text =~ s/^\s+|\s+$//gm;
     addCard(%cards, $set, $name, $id, $cost, $type, $PT, $text);
     $name = $cost = $type = $PT = $text = undef;
    } else {
     my $v1 = simplify textContent $tds->[0];
     my $v2 = textContent $tds->[1];
     if ($v1 eq 'Name:') {
      my $a = $tds->[1]->getElementsByTagName('a')->[0];
      my $href = $a->getAttribute('href');
      $href =~ /multiverseid=(\d+)/ and $id = $1;
      $name = simplify $v2;
     } elsif ($v1 eq 'Cost:') { $cost = simplify $v2 }
     elsif ($v1 eq 'Type:') { $type = simplify $v2 }
     elsif ($v1 eq 'Pow/Tgh:') { ($PT = simplify $v2) =~ tr/()//d }
     elsif ($v1 eq 'Rules Text:') { $text = trim $v2 }
    }
   }
   last;
  }
 }
 return %cards;
}

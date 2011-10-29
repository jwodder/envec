package Oracle;
use Carp;
use XML::DOM::Lite;

my %cardHash;

### Read list of long set names into @allSets; sets that aren't meant to be
### downloaded/imported should be commented out of the list of sets beforehand.

### Read the default set URL into $setUrl

for my $set (@allSets) {
 (my $url = $setUrl) =~ s/!longname!/$set/g;

 ### Download into some file

 ### importTextSpoiler on the contents of the file
}
### Unload the contents of cardHash


sub importTextSpoiler($$) {
 my($set, $data) = @_;
 my $cards = 0;
 ## Workaround for ampersand bug in text spoilers:
 my $index = -1;
 while (($index = index $data, '&', $index + 1) != -1) {
  my $semicolonIndex = index $dat, ';', $index;
  if ($semicolonIndex > 5) {
   substr $data, $index + 1, 0, 'amp;';
   $index += 4;
  }
 }
 my $parser = Parser->new(%options);
 my $doc = $parser->parse($data);
 ##if (!doc.setContent(bufferContents, &errorMsg, &errorLine, &errorColumn))
 ## qDebug() << "error:" << errorMsg << "line:" << errorLine << "column:" << errorColumn;
 for my $div (@{$doc->getElementsByTagName('div')}) {
  my $divClass = $div->getAttribute('class');
  if (defined $divClass && $divClass eq 'textspoiler') {
   my($cardName, $cardCost, $cardType, $cardPT, $cardText);
   my $cardId = 0;
   for my $tr (@{$div->getElementsByTagName('tr')}) {
    my $tds = $tr->getElementsByTagName("td");
    if ($tds->length() != 2) {
     my @cardTextSplit = split /\n/, $cardText;
     s/^\s+|\s+$//g for @cardTextSplit;
     addCard($set->{longName}, $cardName, $cardId, $cardCost, $cardType,
      $cardPt, @cardTextSplit);
     undef $cardName;
     undef $cardCost;
     undef $cardType;
     undef $cardPt;
     undef $cardText;
    } else {
     my $v1 = simplify $tds->[0]->nodeValue;
     my $v2 = $tds->[1]->nodeValue;
      ### PROBLEM: This ^^ is supposed to fetch the textual content of the node.
      ### What does it really do?
     if ($v1 eq 'Name:') {
      my $a = $tds->[1]->getElementsByTagName('a')->[0];
      my $href = $a->getAttribute('href');
      $href =~ /multiverseid=(\d+)/ and $cardId = $1;
      $cardName = simplify $v2;
     } elsif ($v1 eq 'Cost:') { $cardCost = simplify $v2 }
     elsif ($v1 eq 'Type:') { $cardType = simplify $v2 }
     elsif ($v1 eq 'Pow/Tgh:') { ($cardPT = simplify $v2) =~ tr/()//d }
     elsif ($v1 eq 'Rules Text:') { $cardText = trim $v2 }
    }
   }
   last;  ### Why?!?
  }
 }
 return $cards;
}

sub addCard {
 my($setName, $cardName, $cardId, $cardCost, $cardType, $cardPT, @cardText)
  = @_;
 my $fullCardText = join "\n", @cardText;
 my $splitCard = ($cardName =~ s/ \(.*\)//g);
 my $card;
 if (exists $cardHash{$cardName}) {
  $card = $cardHash{$cardName};
  $card->text($card->text() . "\n---\n" . $fullCardText)
   if $splitCard && index($card->text, $fullCardText) == -1;
 } else {
  $cardName =~ s/XX//g;  # Workaround for card name weirdness
  my @colors = grep { $cardCost =~ /$_/ } qw< W U B R G >;
  push @colors, 'W' if elem("$cardName is white.", @cardText);
  push @colors, 'U' if elem("$cardName is blue.", @cardText);
  push @colors, 'B' if elem("$cardName is black.", @cardText);
  push @colors, 'R' if elem("$cardName is red.", @cardText);
  push @colors, 'G' if elem("$cardName is green.", @cardText);
  $card = new CardInfo name => $cardName, manacost => $cardCost,
   cardtype => $cardType, powtough => $cardPT, text => $fullCardText,
   colors => colorStr2Bits(join '', @colors);
  $cardHash{$cardName} = $card;
 }
 $card->sets($setName, $cardId);
 return $card;
}

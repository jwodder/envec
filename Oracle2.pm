package OracleImporter;
use Carp;
use XML::DOM::Lite;

my %cardHash;

### Read sets into @allSets
### Read other data into pictureUrl, pictureUrlHq, pictureUrlSt, and setUrl
for my $set (grep { $_->import } @allSets) {
 ### Download into some file (cf. downloadNextFile)
 ### importTextSpoiler on the contents of the file
}
### Unload the contents of cardHash

sub importTextSpoiler($$) {
 my($set, $data) = @_;  # (CardSet *set, const QByteArray &data)
 my $cards = 0;
 ## Workaround for ampersand bug in text spoilers
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
     my $card = addCard($set->getShortName(), $cardName, $cardId, $cardCost,
      $cardType, $cardPt, @cardTextSplit);
     if (!$set->contains($card)) {
      $card->addToSet($set);
      $cards++;
     }
     undef $cardName;
     undef $cardCost;
     undef $cardType;
     undef $cardPt;
     undef $cardText;
    } else {
     my $v1 = simplify $tds->[0]->nodeValue;
     my $v2 = $tds->[1]->nodeValue;
     ###$v2 =~ s/—/-/g;  # Why does Cockatrice do this?
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
 if ($cardHash->contains($cardName)) {
  $card = $cardHash->value($cardName);
  $card->setText($card->getText() . "\n---\n" . $fullCardText)
   if $splitCard && index($card->getText, $fullCardText) == -1;
 } else {
  # Workaround for card name weirdness
  $cardName =~ s/XX//g;
  ##$cardName =~ s/Æ/AE/g;
  my $mArtifact = ($cardType =~ /Artifact$/
		   && grep { /\{T\}/ && /to your mana pool/ } @cardText);
  my @colors = grep { $cardCost =~ /$_/ } qw< W U B R G >;
  push @colors, 'W' if elem("$cardName is white.", @cardText);
  push @colors, 'U' if elem("$cardName is blue.", @cardText);
  push @colors, 'B' if elem("$cardName is black.", @cardText);
  push @colors, 'R' if elem("$cardName is red.", @cardText);
  push @colors, 'G' if elem("$cardName is green.", @cardText);
  my $cipt = elem("$cardName enters the battlefield tapped.", @cardText);
  $card = new CardInfo $this, $cardName, $cardCost, $cardType, $cardPT,
   $fullCardText, @colors, $cipt;
  my $tableRow = 1;
  my $mainCardType = $card->getMainCardType;
  if ($mainCardType eq "Land" || $mArtifact) { $tableRow = 0 }
  elsif ($mainCardType eq "Sorcery" || $mainCardType eq "Instant") {
   $tableRow = 3
  } elsif ($mainCardType eq "Creature") { $tableRow = 2 }
  $card->setTableRow($tableRow);
  $cardHash->insert($cardName, $card);
 }
 $card->setPicURL($setName, getPictureUrl($pictureUrl, $cardId, $cardName, $setName));
 $card->setPicURLHq($setName, getPictureUrl($pictureUrlHq, $cardId, $cardName, $setName));
 $card->setPicURLSt($setName, getPictureUrl($pictureUrlSt, $cardId, $cardName, $setName));
 return $card;
}

sub getPictureUrl {
 my($url, $cardId, $name, $setName) = @_;
 $name .= '1' if elem($name, qw< Island Swamp Mountain Plains Forest >);
 $url =~ s/!cardid!/$cardId/g;
 $url =~ s/!set!/$setName/g;
 $name =~ s/ö/o/g;
 #$name =~ tr/'//d;
 $name =~ s: // ::g;
 #$name =~ tr/,//d;
 #$name =~ tr/://d;
 #$name =~ tr/.//d;
 $name =~ s/\(.*\)//g;
 $name = simplify $name;
 #$name =~ tr/ /_/;
 #$name =~ tr/-/_/;
 $url =~ s/!name!/$name/g;
 return $url;
}

void OracleImporter::downloadNextFile() {
 my $urlString = $setsToDownload[$setIndex]->url || $setUrl;
 $urlString =~ s/!longname!/$setsToDownload[$setIndex]->longName/ge;
 if (urlString.startsWith("http://")) {
  QUrl url(urlString);
  http->setHost(url.host(), QHttp::ConnectionModeHttp, url.port() == -1 ? 0 : url.port());
  QString path = QUrl::toPercentEncoding(urlString.mid(url.host().size() + 7).replace(' ', '+'), "?!$&'()*+,;=:@/");
  buffer->close();
  buffer->setData(QByteArray());
  buffer->open(QIODevice::ReadWrite | QIODevice::Text);
  reqId = http->get(path, buffer);
 } else {
  QFile file(dataDir + "/" + urlString);
  file.open(QIODevice::ReadOnly | QIODevice::Text);
  buffer->close();
  buffer->setData(file.readAll());
  buffer->open(QIODevice::ReadWrite | QIODevice::Text);
  reqId = 0;
  httpRequestFinished(reqId, false);
 }
}

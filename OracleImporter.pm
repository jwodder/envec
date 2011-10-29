package OracleImporter;
use Carp;
use XML::DOM::Lite;


class OracleImporter : public CardDatabase {
private:
 QList<SetToDownload> allSets, setsToDownload;
 QString pictureUrl, pictureUrlHq, pictureUrlSt, setUrl;
 QString dataDir;
 int setIndex;
 int reqId;
 QBuffer *buffer;
 QHttp *http;

 QString getPictureUrl(QString url, int cardId, QString name, const QString &setName) const;
 void downloadNextFile();
 void readSetsFromXml(QXmlStreamReader &xml);
 CardInfo *addCard(const QString &setName, QString cardName, int cardId, const QString &cardCost, const QString &cardType, const QString &cardPT, const QStringList &cardText);

private slots:
 void httpRequestFinished(int requestId, bool error);
 void readResponseHeader(const QHttpResponseHeader &responseHeader);

signals:
 void setIndexChanged(int cardsImported, int setIndex, const QString &nextSetName);
 void dataReadProgress(int bytesRead, int totalBytes);

public:
 OracleImporter(const QString &_dataDir, QObject *parent = 0);
 void readSetsFromByteArray(const QByteArray &data);
 void readSetsFromFile(const QString &fileName);
 int startDownload();
 int importTextSpoiler(CardSet *set, const QByteArray &data);
 QList<SetToDownload> &getSets() { return allSets; }
 const QString &getDataDir() const { return dataDir; }
};


OracleImporter::OracleImporter(const QString &_dataDir, QObject *parent)
 : CardDatabase(parent), dataDir(_dataDir), setIndex(-1) {
 buffer = new QBuffer(this);
 http = new QHttp(this);
 connect(http, SIGNAL(requestFinished(int, bool)), this, SLOT(httpRequestFinished(int, bool)));
 connect(http, SIGNAL(responseHeaderReceived(const QHttpResponseHeader &)), this, SLOT(readResponseHeader(const QHttpResponseHeader &)));
 connect(http, SIGNAL(dataReadProgress(int, int)), this, SIGNAL(dataReadProgress(int, int)));
}

sub readSetsFromFile {
 my $filename = shift;
 open my $setsFile, '<', $filename or croak "$filename: $!";

 QXmlStreamReader xml(&setsFile);
 readSetsFromXml(xml);
}

void OracleImporter::readSetsFromByteArray(const QByteArray &data) {
 QXmlStreamReader xml(data);
 readSetsFromXml(xml);
}

void OracleImporter::readSetsFromXml(QXmlStreamReader &xml) {
 allSets.clear();
 QString edition;
 QString editionLong;
 QString editionURL;
 while (!xml.atEnd()) {
  if (xml.readNext() == QXmlStreamReader::EndElement) break;
  if (xml.name() == "set") {
   QString shortName, longName;
   bool import = xml.attributes().value("import").toString().toInt();
   while (!xml.atEnd()) {
    if (xml.readNext() == QXmlStreamReader::EndElement) break;
    if (xml.name() == "name") edition = xml.readElementText();
    else if (xml.name() == "longname") editionLong = xml.readElementText();
    else if (xml.name() == "url") editionURL = xml.readElementText();
   }
   allSets << SetToDownload(edition, editionLong, editionURL, import);
   edition = editionLong = editionURL = QString();
  } else if (xml.name() == "picture_url") pictureUrl = xml.readElementText();
  else if (xml.name() == "picture_url_hq") pictureUrlHq = xml.readElementText();
  else if (xml.name() == "picture_url_st") pictureUrlSt = xml.readElementText();
  else if (xml.name() == "set_url") setUrl = xml.readElementText();
 }
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

 ##QDomDocument doc;
 ##QString errorMsg;
 ##int errorLine, errorColumn;
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

int OracleImporter::startDownload() {
 setsToDownload.clear();
 for (int i = 0; i < allSets.size(); ++i)
  if (allSets[i].getImport())
   setsToDownload.append(allSets[i]);
 if (setsToDownload.isEmpty()) return 0;
 setIndex = 0;
 emit setIndexChanged(0, 0, setsToDownload[0].getLongName());
 downloadNextFile();
 return setsToDownload.size();
}

void OracleImporter::downloadNextFile() {
 QString urlString = setsToDownload[setIndex].getUrl();
 if (urlString.isEmpty()) urlString = setUrl;
 urlString = urlString.replace("!longname!", setsToDownload[setIndex].getLongName());
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

void OracleImporter::httpRequestFinished(int requestId, bool error) {
 if (error) {
  QMessageBox::information(0, tr("HTTP"), tr("Error."));
  return;
 }
 if (requestId != reqId) return;
 CardSet *set = new CardSet(setsToDownload[setIndex].getShortName(), setsToDownload[setIndex].getLongName());
 if (!setHash.contains(set->getShortName())) setHash.insert(set->getShortName(), set);
 buffer->seek(0);
 buffer->close();
 int cards = importTextSpoiler(set, buffer->data());
 ++setIndex;
 if (setIndex == setsToDownload.size()) {
  emit setIndexChanged(cards, setIndex, QString());
  setIndex = -1;
 } else {
  downloadNextFile();
  emit setIndexChanged(cards, setIndex, setsToDownload[setIndex].getLongName());
 }
}

void OracleImporter::readResponseHeader(const QHttpResponseHeader &responseHeader) {
 switch (responseHeader.statusCode()) {
  case 200:
  case 301:
  case 302:
  case 303:
  case 307:
   break;
  default:
   QMessageBox::information(0, tr("HTTP"), tr("Download failed: %1.").arg(responseHeader.reasonPhrase()));
   http->abort();
   deleteLater();
 }
}

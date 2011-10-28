package OracleImporter;

use XML::DOM::Lite;


OracleImporter::OracleImporter(const QString &_dataDir, QObject *parent)
 : CardDatabase(parent), dataDir(_dataDir), setIndex(-1) {
 buffer = new QBuffer(this);
 http = new QHttp(this);
 connect(http, SIGNAL(requestFinished(int, bool)), this, SLOT(httpRequestFinished(int, bool)));
 connect(http, SIGNAL(responseHeaderReceived(const QHttpResponseHeader &)), this, SLOT(readResponseHeader(const QHttpResponseHeader &)));
 connect(http, SIGNAL(dataReadProgress(int, int)), this, SIGNAL(dataReadProgress(int, int)));
}

void OracleImporter::readSetsFromFile(const QString &fileName) {
 QFile setsFile(fileName);
 if (!setsFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
  QMessageBox::critical(0, tr("Error"), tr("Cannot open file '%1'.").arg(fileName));
  return;
 }
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

CardInfo *OracleImporter::addCard(const QString &setName, QString cardName, int cardId, const QString &cardCost, const QString &cardType, const QString &cardPT, const QStringList &cardText) {
 QString fullCardText = cardText.join("\n");
 bool splitCard = false;
 if (cardName.contains('(')) {
  cardName.remove(QRegExp(" \\(.*\\)"));
  splitCard = true;
 }
 CardInfo *card;
 if (cardHash.contains(cardName)) {
  card = cardHash.value(cardName);
  if (splitCard && !card->getText().contains(fullCardText))
   card->setText(card->getText() + "\n---\n" + fullCardText);
 } else {
  // Workaround for card name weirdness
  if (cardName.contains("XX")) cardName.remove("XX");
  cardName = cardName.replace("Æ", "AE");
  bool mArtifact = false;
  if (cardType.endsWith("Artifact"))
   for (int i = 0; i < cardText.size(); ++i)
    if (cardText[i].contains("{T}") && cardText[i].contains("to your mana pool")) mArtifact = true;
  QStringList colors;
  QStringList allColors = QStringList() << "W" << "U" << "B" << "R" << "G";
  for (int i = 0; i < allColors.size(); i++)
   if (cardCost.contains(allColors[i]))
    colors << allColors[i];
  if (cardText.contains(cardName + " is white.")) colors << "W";
  if (cardText.contains(cardName + " is blue.")) colors << "U";
  if (cardText.contains(cardName + " is black.")) colors << "B";
  if (cardText.contains(cardName + " is red.")) colors << "R";
  if (cardText.contains(cardName + " is green.")) colors << "G";
  bool cipt = (cardText.contains(cardName + " enters the battlefield tapped."));
  card = new CardInfo(this, cardName, cardCost, cardType, cardPT, fullCardText, colors, cipt);
  int tableRow = 1;
  QString mainCardType = card->getMainCardType();
  if ((mainCardType == "Land") || mArtifact) tableRow = 0;
  else if ((mainCardType == "Sorcery") || (mainCardType == "Instant")) tableRow = 3;
  else if (mainCardType == "Creature") tableRow = 2;
  card->setTableRow(tableRow);
  cardHash.insert(cardName, card);
 }
 card->setPicURL(setName, getPictureUrl(pictureUrl, cardId, cardName, setName));
 card->setPicURLHq(setName, getPictureUrl(pictureUrlHq, cardId, cardName, setName));
 card->setPicURLSt(setName, getPictureUrl(pictureUrlSt, cardId, cardName, setName));
 return card;
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


QString OracleImporter::getPictureUrl(QString url, int cardId, QString name, const QString &setName) const {
 if ((name == "Island") || (name == "Swamp") || (name == "Mountain") || (name == "Plains") || (name == "Forest")) name.append("1");
 return url.replace("!cardid!", QString::number(cardId)).replace("!set!", setName).replace("!name!", name
  .replace("ö", "o")
//  .remove('\'')
  .remove(" // ")
//  .remove(',')
//  .remove(':')
//  .remove('.')
  .remove(QRegExp("\\(.*\\)"))
  .simplified()
//  .replace(' ', '_')
//  .replace('-', '_')
 );
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

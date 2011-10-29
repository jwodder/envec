class CardDatabase : public QObject {
 Q_OBJECT
protected:
 QHash<QString, CardInfo *> cardHash;
 QHash<QString, CardSet *> setHash;
 bool loadSuccess;
 CardInfo *noCard;
 PictureLoadingThread *loadingThread;
private:
 void loadCardsFromXml(QXmlStreamReader &xml);
 void loadSetsFromXml(QXmlStreamReader &xml);
public:
 CardDatabase(QObject *parent = 0);
 ~CardDatabase();
 void clear();
 CardInfo *getCard(const QString &cardName = QString());
 CardSet *getSet(const QString &setName);
 QList<CardInfo *> getCardList() const { return cardHash.values(); }
 SetList getSetList() const;
 bool loadFromFile(const QString &fileName);
 bool saveToFile(const QString &fileName);
 QStringList getAllColors() const;
 QStringList getAllMainCardTypes() const;
 bool getLoadSuccess() const { return loadSuccess; }
 void cacheCardPixmaps(const QStringList &cardNames);
 void loadImage(CardInfo *card);
public slots:
 void clearPixmapCache();
 bool loadCardDatabase(const QString &path);
 bool loadCardDatabase();
private slots:
 void imageLoaded(CardInfo *card, QImage image);
 void picDownloadChanged();
 void picsPathChanged();
signals:
 void cardListChanged();
};

CardDatabase::CardDatabase(QObject *parent)
 : QObject(parent), loadSuccess(false), noCard(0) {
 connect(settingsCache, SIGNAL(picsPathChanged()), this, SLOT(picsPathChanged()));
 connect(settingsCache, SIGNAL(cardDatabasePathChanged()), this, SLOT(loadCardDatabase()));
 connect(settingsCache, SIGNAL(picDownloadChanged()), this, SLOT(picDownloadChanged()));
 
 loadCardDatabase();
 
 loadingThread = new PictureLoadingThread(settingsCache->getPicsPath(), settingsCache->getPicDownload(), this);
 connect(loadingThread, SIGNAL(imageLoaded(CardInfo *, QImage)), this, SLOT(imageLoaded(CardInfo *, QImage)));
 loadingThread->start(QThread::LowPriority);
 loadingThread->waitForInit();

 noCard = new CardInfo(this);
 noCard->loadPixmap(); // cache pixmap for card back
 connect(settingsCache, SIGNAL(cardBackPicturePathChanged()), noCard, SLOT(updatePixmapCache()));
}

CardDatabase::~CardDatabase() {
 clear();
 delete noCard;
}

void CardDatabase::clear() {
 QHashIterator<QString, CardSet *> setIt(setHash);
 while (setIt.hasNext()) {
  setIt.next();
  delete setIt.value();
 }
 setHash.clear();
 QHashIterator<QString, CardInfo *> i(cardHash);
 while (i.hasNext()) {
  i.next();
  delete i.value();
 }
 cardHash.clear();
}

CardInfo *CardDatabase::getCard(const QString &cardName) {
 if (cardName.isEmpty()) return noCard;
 else if (cardHash.contains(cardName)) return cardHash.value(cardName);
 else {
  CardInfo *newCard = new CardInfo(this, cardName);
  newCard->addToSet(getSet("TK"));
  cardHash.insert(cardName, newCard);
  return newCard;
 }
}

CardSet *CardDatabase::getSet(const QString &setName) {
 if (setHash.contains(setName)) return setHash.value(setName);
 else {
  CardSet *newSet = new CardSet(setName);
  setHash.insert(setName, newSet);
  return newSet;
 }
}

SetList CardDatabase::getSetList() const {
 SetList result;
 QHashIterator<QString, CardSet *> i(setHash);
 while (i.hasNext()) {
  i.next();
  result << i.value();
 }
 return result;
}

void CardDatabase::clearPixmapCache() {
 QHashIterator<QString, CardInfo *> i(cardHash);
 while (i.hasNext()) {
  i.next();
  i.value()->clearPixmapCache();
 }
 if (noCard) noCard->clearPixmapCache();
}

void CardDatabase::loadSetsFromXml(QXmlStreamReader &xml) {
 while (!xml.atEnd()) {
  if (xml.readNext() == QXmlStreamReader::EndElement) break;
  if (xml.name() == "set") {
   QString shortName, longName;
   while (!xml.atEnd()) {
    if (xml.readNext() == QXmlStreamReader::EndElement) break;
    if (xml.name() == "name") shortName = xml.readElementText();
    else if (xml.name() == "longname") longName = xml.readElementText();
   }
   setHash.insert(shortName, new CardSet(shortName, longName));
  }
 }
}

void CardDatabase::loadCardsFromXml(QXmlStreamReader &xml) {
 while (!xml.atEnd()) {
  if (xml.readNext() == QXmlStreamReader::EndElement) break;
  if (xml.name() == "card") {
   QString name, manacost, type, pt, text;
   QStringList colors;
   QMap<QString, QString> picURLs, picURLsHq, picURLsSt;
   SetList sets;
   int tableRow = 0;
   bool cipt = false;
   while (!xml.atEnd()) {
    if (xml.readNext() == QXmlStreamReader::EndElement) break;
    if (xml.name() == "name") name = xml.readElementText();
    else if (xml.name() == "manacost") manacost = xml.readElementText();
    else if (xml.name() == "type") type = xml.readElementText();
    else if (xml.name() == "pt") pt = xml.readElementText();
    else if (xml.name() == "text") text = xml.readElementText();
    else if (xml.name() == "set") {
     QString picURL = xml.attributes().value("picURL").toString();
     QString picURLHq = xml.attributes().value("picURLHq").toString();
     QString picURLSt = xml.attributes().value("picURLSt").toString();
     QString setName = xml.readElementText();
     sets.append(getSet(setName));
     picURLs.insert(setName, picURL);
     picURLsHq.insert(setName, picURLHq);
     picURLsSt.insert(setName, picURLSt);
    } else if (xml.name() == "color") colors << xml.readElementText();
    else if (xml.name() == "tablerow") tableRow = xml.readElementText().toInt();
    else if (xml.name() == "cipt") cipt = (xml.readElementText() == "1");
   }
   cardHash.insert(name, new CardInfo(this, name, manacost, type, pt, text, colors, cipt, tableRow, sets, picURLs, picURLsHq, picURLsSt));
  }
 }
}

bool CardDatabase::loadFromFile(const QString &fileName) {
 QFile file(fileName);
 file.open(QIODevice::ReadOnly);
 if (!file.isOpen()) return false;
 QXmlStreamReader xml(&file);
 clear();
 while (!xml.atEnd()) {
  if (xml.readNext() == QXmlStreamReader::StartElement) {
   if (xml.name() != "cockatrice_carddatabase") return false;
   while (!xml.atEnd()) {
    if (xml.readNext() == QXmlStreamReader::EndElement) break;
    if (xml.name() == "sets") loadSetsFromXml(xml);
    else if (xml.name() == "cards") loadCardsFromXml(xml);
   }
  }
 }
 qDebug() << cardHash.size() << "cards in" << setHash.size() << "sets loaded";
 return !cardHash.isEmpty();
}

bool CardDatabase::saveToFile(const QString &fileName) {
 QFile file(fileName);
 if (!file.open(QIODevice::WriteOnly)) return false;
 QXmlStreamWriter xml(&file);

 xml.setAutoFormatting(true);
 xml.writeStartDocument();
 xml.writeStartElement("cockatrice_carddatabase");
 xml.writeAttribute("version", "1");

 xml.writeStartElement("sets");
 QHashIterator<QString, CardSet *> setIterator(setHash);
 while (setIterator.hasNext())
  xml << setIterator.next().value();
 xml.writeEndElement(); // sets

 xml.writeStartElement("cards");
 QHashIterator<QString, CardInfo *> cardIterator(cardHash);
 while (cardIterator.hasNext())
  xml << cardIterator.next().value();
 xml.writeEndElement(); // cards

 xml.writeEndElement(); // cockatrice_carddatabase
 xml.writeEndDocument();

 return true;
}

void CardDatabase::picDownloadChanged() {
 loadingThread->getPictureLoader()->setPicDownload(settingsCache->getPicDownload());
 if (settingsCache->getPicDownload()) {
  QHashIterator<QString, CardInfo *> cardIterator(cardHash);
  while (cardIterator.hasNext())
   cardIterator.next().value()->clearPixmapCacheMiss();
 }
}

bool CardDatabase::loadCardDatabase(const QString &path) {
 if (!path.isEmpty()) loadSuccess = loadFromFile(path);
 else loadSuccess = false;
 if (loadSuccess) {
  SetList allSets;
  QHashIterator<QString, CardSet *> setsIterator(setHash);
  while (setsIterator.hasNext()) allSets.append(setsIterator.next().value());
  allSets.sortByKey();
  for (int i = 0; i < allSets.size(); ++i) allSets[i]->setSortKey(i);
  emit cardListChanged();
 }
 return loadSuccess;
}

bool CardDatabase::loadCardDatabase() {
 return loadCardDatabase(settingsCache->getCardDatabasePath());
}

QStringList CardDatabase::getAllColors() const {
 QSet<QString> colors;
 QHashIterator<QString, CardInfo *> cardIterator(cardHash);
 while (cardIterator.hasNext()) {
  const QStringList &cardColors = cardIterator.next().value()->getColors();
  if (cardColors.isEmpty()) colors.insert("X");
  else for (int i = 0; i < cardColors.size(); ++i)
    colors.insert(cardColors[i]);
 }
 return colors.toList();
}

QStringList CardDatabase::getAllMainCardTypes() const {
 QSet<QString> types;
 QHashIterator<QString, CardInfo *> cardIterator(cardHash);
 while (cardIterator.hasNext())
  types.insert(cardIterator.next().value()->getMainCardType());
 return types.toList();
}

void CardDatabase::cacheCardPixmaps(const QStringList &cardNames) {
 for (int i = 0; i < cardNames.size(); ++i)
  getCard(cardNames[i])->loadPixmap();
}

void CardDatabase::loadImage(CardInfo *card) {
 loadingThread->getPictureLoader()->loadImage(card, false);
}

void CardDatabase::imageLoaded(CardInfo *card, QImage image) {
 card->imageLoaded(image);
}

void CardDatabase::picsPathChanged() {
 loadingThread->getPictureLoader()->setPicsPath(settingsCache->getPicsPath());
 clearPixmapCache();
}

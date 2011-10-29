# TODO: Replace the class implementation with a Class::Struct

package CardInfo;

typedef QMap<QString, QString> QStringMap;

class CardInfo : public QObject {
 Q_OBJECT
private:
 ...
 QPixmap *pixmap;
 QMap<int, QPixmap *> scaledPixmapCache;
public:
 const QString &getName() const { return name; }
 const SetList &getSets() const { return sets; }
 const QString &getManaCost() const { return manacost; }
 const QString &getCardType() const { return cardtype; }
 const QString &getPowTough() const { return powtough; }
 const QString &getText() const { return text; }
 bool getCipt() const { return cipt; }
 void setText(const QString &_text) { text = _text; }
 const QStringList &getColors() const { return colors; }
 QString getPicURL(const QString &set) const { return picURLs.value(set); }
 QString getPicURLHq(const QString &set) const { return picURLsHq.value(set); }
 QString getPicURLSt(const QString &set) const { return picURLsSt.value(set); }
 const QMap<QString, QString> &getPicURLs() const { return picURLs; }
 int getTableRow() const { return tableRow; }
 void setTableRow(int _tableRow) { tableRow = _tableRow; }
 void setPicURL(const QString &_set, const QString &_picURL) { picURLs.insert(_set, _picURL); }
 void setPicURLHq(const QString &_set, const QString &_picURL) { picURLsHq.insert(_set, _picURL); }
 void setPicURLSt(const QString &_set, const QString &_picURL) { picURLsSt.insert(_set, _picURL); }

 QString getPicURL() const;
 QString getMainCardType() const;
 QString getCorrectedName() const;
 void addToSet(CardSet *set);
 QPixmap *loadPixmap();
 QPixmap *getPixmap(QSize size);
 void clearPixmapCache();
 void clearPixmapCacheMiss();
 void imageLoaded(const QImage &image);

public slots:
 void updatePixmapCache();
signals:
 void pixmapUpdated();
};


sub new {
 my %self = ();
 my $class = shift;
 $self{db} = shift;  # CardDatabase*
 $self{name} = shift;
 $self{manacost} = shift;
 $self{cardtype} = shift;
 $self{powtough} = shift;
 $self{text} = shift;
 $self{colors} = shift;  # QStringList
 $self{cipt} = shift || 0;  # bool; seems to mean "comes into play tapped"
 $self{tableRow} = shift || 0;  # int
 $self{sets} = shift || [];  # SetList
 $self{picURLs} = shift || {};  # QMap<QString, QString>
 $self{picURLsHq} = shift || {};  # QMap<QString, QString>
 $self{picURLsSt} = shift || {};  # QMap<QString, QString>
 $self{pixmap} = undef;
 my $blessed = bless { %self }, ref $class || $class;
 $_->append($blessed) for @{$self{sets}};
 return $blessed;
}

sub DESTROY { $_[0]->clearPixMapCache }

sub getMainCardType {
 my $result = $_[0]->getCardType;
 # Legendary Artifact Creature - Golem
 # Instant // Instant
 $result =~ s/-.*$//;  # How should this handle U+2014?
 $result =~ s://.*$::;
 # Legendary Artifact Creature
 # Instant
 my @words = split ' ', $result;
 return $words[$#words];
 # Creature
 # Instant
}

sub getCorrectedName {
 my $result = $_[0]->{name};
 # Fire // Ice, Circle of Protection: Red
 $result =~ s: // ::g;
 $result =~ y/://d;
 return $result;
}

sub addToSet {  ## (CardSet *set)
 my($self, $set) = @_;
 $set->append($self);
 push @{$self->{sets}}, $set;
}

QString CardInfo::getPicURL() const {
 SetList sortedSets = sets;
 sortedSets.sortByKey();
 return picURLs.value(sortedSets.first()->getShortName());
}

QPixmap *CardInfo::loadPixmap() {
 if (pixmap) return pixmap;
 pixmap = new QPixmap();
 if (getName().isEmpty()) {
  pixmap->load(settingsCache->getCardBackPicturePath());
  return pixmap;
 }
 db->loadImage(this);
 return pixmap;
}

void CardInfo::imageLoaded(const QImage &image) {
 if (!image.isNull()) {
  *pixmap = QPixmap::fromImage(image);
  emit pixmapUpdated();
 }
}

QPixmap *CardInfo::getPixmap(QSize size) {
 QPixmap *cachedPixmap = scaledPixmapCache.value(size.width());
 if (cachedPixmap) return cachedPixmap;
 QPixmap *bigPixmap = loadPixmap();
 QPixmap *result;
 if (bigPixmap->isNull()) {
  if (!getName().isEmpty()) return 0;
  else {
   result = new QPixmap(size);
   result->fill(Qt::transparent);
   QSvgRenderer svg(QString(":/back.svg"));
   QPainter painter(result);
   svg.render(&painter, QRectF(0, 0, size.width(), size.height()));
  }
 } else result = new QPixmap(bigPixmap->scaled(size, Qt::IgnoreAspectRatio, Qt::SmoothTransformation));
 scaledPixmapCache.insert(size.width(), result);
 return result;
}

void CardInfo::clearPixmapCache() {
 if (pixmap) {
  qDebug() << "Deleting pixmap for" << name;
  delete pixmap;
  pixmap = 0;
  QMapIterator<int, QPixmap *> i(scaledPixmapCache);
  while (i.hasNext()) {
   i.next();
   qDebug() << "  Deleting cached pixmap for width" << i.key();
   delete i.value();
  }
  scaledPixmapCache.clear();
 }
}

void CardInfo::clearPixmapCacheMiss() {
 if (!pixmap) return;
 if (pixmap->isNull()) clearPixmapCache();
}

void CardInfo::updatePixmapCache() {
 qDebug() << "Updating pixmap cache for" << name;
 clearPixmapCache();
 loadPixmap();
 emit pixmapUpdated();
}

QXmlStreamWriter &operator<<(QXmlStreamWriter &xml, const CardInfo *info) {
 xml.writeStartElement("card");
 xml.writeTextElement("name", info->getName());
 const SetList &sets = info->getSets();
 for (int i = 0; i < sets.size(); i++) {
  xml.writeStartElement("set");
  xml.writeAttribute("picURL", info->getPicURL(sets[i]->getShortName()));
  xml.writeAttribute("picURLHq", info->getPicURLHq(sets[i]->getShortName()));
  xml.writeAttribute("picURLSt", info->getPicURLSt(sets[i]->getShortName()));
  xml.writeCharacters(sets[i]->getShortName());
  xml.writeEndElement();
 }
 const QStringList &colors = info->getColors();
 for (int i = 0; i < colors.size(); i++)
  xml.writeTextElement("color", colors[i]);
 xml.writeTextElement("manacost", info->getManaCost());
 xml.writeTextElement("type", info->getCardType());
 if (!info->getPowTough().isEmpty()) xml.writeTextElement("pt", info->getPowTough());
 xml.writeTextElement("tablerow", QString::number(info->getTableRow()));
 xml.writeTextElement("text", info->getText());
 if (info->getCipt()) xml.writeTextElement("cipt", "1");
 xml.writeEndElement(); // card
 return xml;
}

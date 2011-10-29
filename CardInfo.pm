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
};


sub new {
 my %self = ();
 my $class = shift;
 $self{db} = shift;  # CardDatabase*; only needed for loading images
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
 my $blessed = bless { %self }, ref $class || $class;
 $_->append($blessed) for @{$self{sets}};
 return $blessed;
}

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

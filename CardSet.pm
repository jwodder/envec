package CardSet;  # extends QList<CardInfo*>
use Class::Struct list => '@', shortName => '$', longName => '$',
 sortKey => '$';

QXmlStreamWriter &operator<<(QXmlStreamWriter &xml, const CardSet *set) {
 xml.writeStartElement("set");
 xml.writeTextElement("name", set->getShortName());
 xml.writeTextElement("longname", set->getLongName());
 xml.writeEndElement();
 return xml;
}

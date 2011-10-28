class CardSet : public QList<CardInfo *> {
private:
	QString shortName, longName;
	unsigned int sortKey;
public:
	CardSet(const QString &_shortName = QString(), const QString &_longName = QString());
	QString getShortName() const { return shortName; }
	QString getLongName() const { return longName; }
	int getSortKey() const { return sortKey; }
	void setSortKey(unsigned int _sortKey);
	void updateSortKey();
};

CardSet::CardSet(const QString &_shortName, const QString &_longName)
	: shortName(_shortName), longName(_longName)
{
	updateSortKey();
}

QXmlStreamWriter &operator<<(QXmlStreamWriter &xml, const CardSet *set)
{
	xml.writeStartElement("set");
	xml.writeTextElement("name", set->getShortName());
	xml.writeTextElement("longname", set->getLongName());
	xml.writeEndElement();

	return xml;
}

void CardSet::setSortKey(unsigned int _sortKey)
{
	sortKey = _sortKey;

	QSettings settings;
	settings.beginGroup("sets");
	settings.beginGroup(shortName);
	settings.setValue("sortkey", sortKey);
}

void CardSet::updateSortKey()
{
	QSettings settings;
	settings.beginGroup("sets");
	settings.beginGroup(shortName);
	sortKey = settings.value("sortkey", 0).toInt();
}



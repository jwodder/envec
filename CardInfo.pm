typedef QMap<QString, QString> QStringMap;

class CardInfo : public QObject {
	Q_OBJECT
private:
	CardDatabase *db;

	QString name;
	SetList sets;
	QString manacost;
	QString cardtype;
	QString powtough;
	QString text;
	QStringList colors;
	QMap<QString, QString> picURLs, picURLsHq, picURLsSt;
	bool cipt;
	int tableRow;
	QPixmap *pixmap;
	QMap<int, QPixmap *> scaledPixmapCache;
public:
	CardInfo(CardDatabase *_db,
		const QString &_name = QString(),
		const QString &_manacost = QString(),
		const QString &_cardtype = QString(),
		const QString &_powtough = QString(),
		const QString &_text = QString(),
		const QStringList &_colors = QStringList(),
		bool cipt = false,
		int _tableRow = 0,
		const SetList &_sets = SetList(),
		const QStringMap &_picURLs = QStringMap(),
		const QStringMap &_picURLsHq = QStringMap(),
		const QStringMap &_picURLsSt = QStringMap());
	~CardInfo();
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
	QString getPicURL() const;
	const QMap<QString, QString> &getPicURLs() const { return picURLs; }
	QString getMainCardType() const;
	QString getCorrectedName() const;
	int getTableRow() const { return tableRow; }
	void setTableRow(int _tableRow) { tableRow = _tableRow; }
	void setPicURL(const QString &_set, const QString &_picURL) { picURLs.insert(_set, _picURL); }
	void setPicURLHq(const QString &_set, const QString &_picURL) { picURLsHq.insert(_set, _picURL); }
	void setPicURLSt(const QString &_set, const QString &_picURL) { picURLsSt.insert(_set, _picURL); }
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

CardInfo::CardInfo(CardDatabase *_db, const QString &_name, const QString &_manacost, const QString &_cardtype, const QString &_powtough, const QString &_text, const QStringList &_colors, bool _cipt, int _tableRow, const SetList &_sets, const QMap<QString, QString> &_picURLs, const QMap<QString, QString> &_picURLsHq, const QMap<QString, QString> &_picURLsSt)
	: db(_db), name(_name), sets(_sets), manacost(_manacost), cardtype(_cardtype), powtough(_powtough), text(_text), colors(_colors), picURLs(_picURLs), picURLsHq(_picURLsHq), picURLsSt(_picURLsSt), cipt(_cipt), tableRow(_tableRow), pixmap(NULL)
{
	for (int i = 0; i < sets.size(); i++)
		sets[i]->append(this);
}

CardInfo::~CardInfo()
{
	clearPixmapCache();
}

QString CardInfo::getMainCardType() const
{
	QString result = getCardType();
	/*
	Legendary Artifact Creature - Golem
	Instant // Instant
	*/

	int pos;
	if ((pos = result.indexOf('-')) != -1)
		result.remove(pos, result.length());
	if ((pos = result.indexOf("//")) != -1)
		result.remove(pos, result.length());
	result = result.simplified();
	/*
	Legendary Artifact Creature
	Instant
	*/

	if ((pos = result.lastIndexOf(' ')) != -1)
		result = result.mid(pos + 1);
	/*
	Creature
	Instant
	*/

	return result;
}

QString CardInfo::getCorrectedName() const
{
	QString result = name;
	// Fire // Ice, Circle of Protection: Red
	return result.remove(" // ").remove(":");
}

void CardInfo::addToSet(CardSet *set)
{
	set->append(this);
	sets << set;
}

QString CardInfo::getPicURL() const
{
	SetList sortedSets = sets;
	sortedSets.sortByKey();
	return picURLs.value(sortedSets.first()->getShortName());
}

QPixmap *CardInfo::loadPixmap()
{
	if (pixmap)
		return pixmap;
	pixmap = new QPixmap();
	
	if (getName().isEmpty()) {
		pixmap->load(settingsCache->getCardBackPicturePath());
		return pixmap;
	}
	db->loadImage(this);
	return pixmap;
}

void CardInfo::imageLoaded(const QImage &image)
{
	if (!image.isNull()) {
		*pixmap = QPixmap::fromImage(image);
		emit pixmapUpdated();
	}
}

QPixmap *CardInfo::getPixmap(QSize size)
{
	QPixmap *cachedPixmap = scaledPixmapCache.value(size.width());
	if (cachedPixmap)
		return cachedPixmap;
	QPixmap *bigPixmap = loadPixmap();
	QPixmap *result;
	if (bigPixmap->isNull()) {
		if (!getName().isEmpty())
			return 0;
		else {
			result = new QPixmap(size);
			result->fill(Qt::transparent);
			QSvgRenderer svg(QString(":/back.svg"));
			QPainter painter(result);
			svg.render(&painter, QRectF(0, 0, size.width(), size.height()));
		}
	} else
		result = new QPixmap(bigPixmap->scaled(size, Qt::IgnoreAspectRatio, Qt::SmoothTransformation));
	scaledPixmapCache.insert(size.width(), result);
	return result;
}

void CardInfo::clearPixmapCache()
{
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

void CardInfo::clearPixmapCacheMiss()
{
	if (!pixmap)
		return;
	if (pixmap->isNull())
		clearPixmapCache();
}

void CardInfo::updatePixmapCache()
{
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
	if (!info->getPowTough().isEmpty())
		xml.writeTextElement("pt", info->getPowTough());
	xml.writeTextElement("tablerow", QString::number(info->getTableRow()));
	xml.writeTextElement("text", info->getText());
	if (info->getCipt())
		xml.writeTextElement("cipt", "1");
	xml.writeEndElement(); // card

	return xml;
}

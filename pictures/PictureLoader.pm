class PictureLoader : public QObject {
	Q_OBJECT
private:
	QString _picsPath;
	QList<PictureToLoad> loadQueue;
	QMutex mutex;
	QNetworkAccessManager *networkManager;
	QList<PictureToLoad> cardsToDownload;
	PictureToLoad cardBeingDownloaded;
	bool picDownload, downloadRunning, loadQueueRunning;
	void startNextPicDownload();
public:
	PictureLoader(QObject *parent = 0);
	void setPicsPath(const QString &path);
	void setPicDownload(bool _picDownload);
	void loadImage(CardInfo *card, bool stripped);
private slots:
	void picDownloadFinished(QNetworkReply *reply);
public slots:
	void processLoadQueue();
signals:
	void startLoadQueue();
	void imageLoaded(CardInfo *card, const QImage &image);
};

PictureLoader::PictureLoader(QObject *parent)
	: QObject(parent), downloadRunning(false), loadQueueRunning(false)
{
	connect(this, SIGNAL(startLoadQueue()), this, SLOT(processLoadQueue()), Qt::QueuedConnection);
	
	networkManager = new QNetworkAccessManager(this);
	connect(networkManager, SIGNAL(finished(QNetworkReply *)), this, SLOT(picDownloadFinished(QNetworkReply *)));
}

void PictureLoader::processLoadQueue()
{
	if (loadQueueRunning)
		return;
	
	loadQueueRunning = true;
	forever {
		mutex.lock();
		if (loadQueue.isEmpty()) {
			mutex.unlock();
			loadQueueRunning = false;
			return;
		}
		PictureToLoad ptl = loadQueue.takeFirst();
		mutex.unlock();
		QString correctedName = ptl.getCard()->getCorrectedName();
		QString picsPath = _picsPath;
		QString setName = ptl.getSetName();
		
		QImage image;
		if (!image.load(QString("%1/%2/%3.full.jpg").arg(picsPath).arg(setName).arg(correctedName)))
			if (!image.load(QString("%1/%2/%3%4.full.jpg").arg(picsPath).arg(setName).arg(correctedName).arg(1)))
				if (!image.load(QString("%1/%2/%3/%4.full.jpg").arg(picsPath).arg("downloadedPics").arg(setName).arg(correctedName))) {
					if (picDownload) {
						cardsToDownload.append(ptl);
						if (!downloadRunning)
							startNextPicDownload();
					} else {
						if (ptl.nextSet())
							loadQueue.prepend(ptl);
						else
							emit imageLoaded(ptl.getCard(), QImage());
					}
					continue;
				}
		
		emit imageLoaded(ptl.getCard(), image);
	}
}

void PictureLoader::startNextPicDownload()
{
	if (cardsToDownload.isEmpty()) {
		cardBeingDownloaded = 0;
		downloadRunning = false;
		return;
	}
	
	downloadRunning = true;
	
	cardBeingDownloaded = cardsToDownload.takeFirst();
	QString picUrl;
	if (cardBeingDownloaded.getStripped())
		picUrl = cardBeingDownloaded.getCard()->getPicURLSt(cardBeingDownloaded.getSetName());
	else if (cardBeingDownloaded.getHq())
		picUrl = cardBeingDownloaded.getCard()->getPicURLHq(cardBeingDownloaded.getSetName());
	else
		picUrl = cardBeingDownloaded.getCard()->getPicURL(cardBeingDownloaded.getSetName());
	QUrl url(picUrl);
	
	QNetworkRequest req(url);
	qDebug() << "starting picture download:" << req.url();
	networkManager->get(req);
}

void PictureLoader::picDownloadFinished(QNetworkReply *reply)
{
	QString picsPath = _picsPath;
	const QByteArray &picData = reply->readAll();
	QImage testImage;
	if (testImage.loadFromData(picData)) {
		if (!QDir(QString(picsPath + "/downloadedPics/")).exists()) {
			QDir dir(picsPath);
			if (!dir.exists())
				return;
			dir.mkdir("downloadedPics");
		}
		if (!QDir(QString(picsPath + "/downloadedPics/" + cardBeingDownloaded.getSetName())).exists()) {
			QDir dir(QString(picsPath + "/downloadedPics"));
			dir.mkdir(cardBeingDownloaded.getSetName());
		}
		
		QString suffix;
		if (!cardBeingDownloaded.getStripped())
			suffix = ".full";
		
		QFile newPic(picsPath + "/downloadedPics/" + cardBeingDownloaded.getSetName() + "/" + cardBeingDownloaded.getCard()->getCorrectedName() + suffix + ".jpg");
		if (!newPic.open(QIODevice::WriteOnly))
			return;
		newPic.write(picData);
		newPic.close();
		
		emit imageLoaded(cardBeingDownloaded.getCard(), testImage);
	} else if (cardBeingDownloaded.getHq()) {
		qDebug() << "HQ: received invalid picture. URL:" << reply->request().url();
		cardBeingDownloaded.setHq(false);
		cardsToDownload.prepend(cardBeingDownloaded);
	} else {
		qDebug() << "LQ: received invalid picture. URL:" << reply->request().url();
		if (cardBeingDownloaded.nextSet()) {
			cardBeingDownloaded.setHq(true);
			mutex.lock();
			loadQueue.prepend(cardBeingDownloaded);
			mutex.unlock();
			emit startLoadQueue();
		} else
			emit imageLoaded(cardBeingDownloaded.getCard(), QImage());
	}
	
	reply->deleteLater();
	startNextPicDownload();
}

void PictureLoader::loadImage(CardInfo *card, bool stripped)
{
	QMutexLocker locker(&mutex);
	
	loadQueue.append(PictureToLoad(card, stripped));
	emit startLoadQueue();
}

void PictureLoader::setPicsPath(const QString &path)
{
	QMutexLocker locker(&mutex);
	_picsPath = path;
}

void PictureLoader::setPicDownload(bool _picDownload)
{
	QMutexLocker locker(&mutex);
	picDownload = _picDownload;
}

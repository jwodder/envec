class PictureLoadingThread : public QThread {
	Q_OBJECT
private:
	QString picsPath;
	bool picDownload;
	PictureLoader *pictureLoader;
	QWaitCondition initWaitCondition;
protected:
	void run();
public:
	PictureLoadingThread(const QString &_picsPath, bool _picDownload, QObject *parent);
	~PictureLoadingThread();
	PictureLoader *getPictureLoader() const { return pictureLoader; }
	void waitForInit();
signals:
	void imageLoaded(CardInfo *card, const QImage &image);
};

PictureLoadingThread::PictureLoadingThread(const QString &_picsPath, bool _picDownload, QObject *parent)
	: QThread(parent), picsPath(_picsPath), picDownload(_picDownload)
{
}

PictureLoadingThread::~PictureLoadingThread()
{
	quit();
	wait();
}

void PictureLoadingThread::run()
{
	pictureLoader = new PictureLoader;
	connect(pictureLoader, SIGNAL(imageLoaded(CardInfo *, const QImage &)), this, SIGNAL(imageLoaded(CardInfo *, const QImage &)));
	pictureLoader->setPicsPath(picsPath);
	pictureLoader->setPicDownload(picDownload);
	
	usleep(100);
	initWaitCondition.wakeAll();
	
	exec();
	
	delete pictureLoader;
}

void PictureLoadingThread::waitForInit()
{
	QMutex mutex;
	mutex.lock();
	initWaitCondition.wait(&mutex);
	mutex.unlock();
}

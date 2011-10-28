class PictureToLoad {
private:
	CardInfo *card;
	bool stripped;
	SetList sortedSets;
	int setIndex;
	bool hq;
public:
	PictureToLoad(CardInfo *_card = 0, bool _stripped = false, bool _hq = true);
	CardInfo *getCard() const { return card; }
	bool getStripped() const { return stripped; }
	QString getSetName() const { return sortedSets[setIndex]->getShortName(); }
	bool nextSet();
		
	bool getHq() const { return hq; }
	void setHq(bool _hq) { hq = _hq; }
	
};

PictureToLoad::PictureToLoad(CardInfo *_card, bool _stripped, bool _hq)
	: card(_card), stripped(_stripped), setIndex(0), hq(_hq)
{
	if (card) {
		sortedSets = card->getSets();
		sortedSets.sortByKey();
	}
}

bool PictureToLoad::nextSet()
{
	if (setIndex == sortedSets.size() - 1)
		return false;
	++setIndex;
	return true;
}



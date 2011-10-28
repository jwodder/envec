class SetList : public QList<CardSet *> {
private:
	class CompareFunctor;
public:
	void sortByKey();
};

class SetList::CompareFunctor {
public:
	inline bool operator()(CardSet *a, CardSet *b) const
	{
		return a->getSortKey() < b->getSortKey();
	}
};

void SetList::sortByKey()
{
	qSort(begin(), end(), CompareFunctor());
}



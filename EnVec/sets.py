import re
from warnings import warn
from envec.util import openR, chomp

setFile = 'data/sets.tsv'
setDB = None

class CardSet(object):
    def __init__(self, name, date, short, _import):
	self.name = name
	self.date = filter(str.isdigit, date)
	self.short = short
	self._import = _import

    def __cmp__(self, other):
	return cmp(type(self), type(other)) or \
	       cmp((self.date,  self.name,  self.short,  self._import),
		   (other.date, other.name, other.short, other._import))

    def cmpKey(self): return self.date or self.name

class CardSetDB(object):
    @staticmethod
    def fromFile(infile=None):
	if infile is None: infile = setFile
	setdat = openR(infile, 'envec.sets.CardSetDB.fromFile')
	self = CardSetDB()
	self.sets = dict()
	self.shorts = dict()
	self.setList = []
	for line in setdat:
	    line = chomp(line)
	    if line.lstrip() == '' or line.lstrip()[0] == '#':
		continue
	    (short, name, date, _import) = re.split(r'\t+', line)
	    if name in self.sets:
		warn(infile ++ ': set "' + name + '" appears more than once; second appearance discarded')
		continue
	    newSet = CardSet(name, date, short, _import)
	    self.sets[name] = newSet
	    self.setList.append(name)
	    if short in self.shorts:
		warn(infile + ': abbreviation "' + short + '" used more than once; second appearance ignored')
	    else:
		self.shorts[short] = name
	setdat.close()
	return self

    def setData(self, name): return self.sets.get(name, None)

    def allSets(self): return self.setList[:]

    def fromAbbrev(self, short): return self.shorts.get(short, None)

    def setsToImport(self):
	return filter(lambda s: self.sets[s]._import, self.setList)

    def cmpKey(self, name):
	return self.sets[name].cmpKey() if name in self.sets else name

    def cmpSets(self, a, b):
	return cmp(self.cmpKey(a), self.cmpKey(b)) or cmp(a,b)

    def firstSet(self, xs): return min(xs, key=self.cmpKey)

def loadSets(infile=None): return setDB = CardSetDB.fromFile(infile)

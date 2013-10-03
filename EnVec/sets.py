### TODO: Make CardSetDB objects store the name of the file from which they
### were constructed

### Add a method for getting the number of entries in a CardSetDB (and other
### deconstructions)?
###  - Iterating over a CardSetDB should probably give the setList

import re
from warnings import warn
from envec.util import openR, chomp

setFile = 'data/sets.tsv'
setDB = None

class CardSet(object):
    def __init__(self, name, date, short, import_):
	self.name = name
	self.date = filter(str.isdigit, date)
	self.short = short
	self.import_ = import_

    def __cmp__(self, other):
	return cmp(type(self), type(other)) or \
	       cmp((self.date,  self.name,  self.short,  self.import_),
		   (other.date, other.name, other.short, other.import_))

    def cmpKey(self): return self.date or self.name

    def __str__(self): return self.name

class CardSetDB(object):
    def __init__(self, sets, shorts, setList):
	self.sets = sets
	self.shorts = shorts
	self.setList = setList

    @classmethod
    def fromFile(cls, infile=None):
	if infile is None: infile = setFile
	setdat = openR(infile)
	sets = {}
	shorts = {}
	setList = []
	for line in setdat:
	    line = chomp(line)
	    if line.lstrip()[:1] in ('', '#'): continue
	    (short, name, date, import_) = re.split(r'\t+', line)
	    if name in sets:
		warn('%s: set %r appears more than once; second appearance discarded' % (infile, name))
		continue
	    newSet = CardSet(name, date, short, import_)
	    sets[name] = newSet
	    setList.append(name)
	    if short in shorts:
		warn('%s: abbreviation %r used more than once; second appearance ignored' % (infile, short))
	    else:
		shorts[short] = name
	setdat.close()
	return cls(sets, shorts, setList)

    def setData(self, name): return self.sets.get(name, None)

    def allSets(self): return self.setList[:]

    def fromAbbrev(self, short): return self.shorts.get(short, None)

    def setsToImport(self):
	return filter(lambda s: self.sets[s].import_, self.setList)

    def cmpKey(self, name):
	return (self.sets[name].cmpKey() if name in self.sets else name, name)

    def cmpSets(self, a, b): return cmp(self.cmpKey(a), self.cmpKey(b))

    def firstSet(self, xs): return min(xs, key=self.cmpKey)

def loadSets(infile=None):  ### Rename "loadCardSetDB"?
    global setDB
    setDB = CardSetDB.fromFile(infile)
    return setDB

def getCardSetDB(): return CardSetDB({}, {}, []) if setDB is None else setDB

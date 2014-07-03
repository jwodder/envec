### TODO: Make MultipartDB objects store the name of the file from which they
### were constructed

### Add a method for getting the number of entries in a MultipartDB (and other
### deconstructions)?

import re
from warnings   import warn
from envec.util import openR, chomp

### Shouldn't these be MultipartDB class variables?
multiFile = 'data/multipart.tsv'
multiDB = None

class MultipartDB(object):
    def __init__(self, nextMap, prevMap, classMap):
	self.nextMap = nextMap
	self.prevMap = prevMap
	self.classMap = classMap

    @classmethod
    def fromFile(cls, infile=None):
	if infile is None: infile = multiFile
	nextMap = {}
	prevMap = {}
	classMap = {}
	lineno = 0
	for line in openR(infile):
	    lineno += 1
	    line = chomp(line)
	    if line.lstrip()[:1] in ('', '#'): continue
	    try:
		(a, b, enum) = re.split(r'\t+', line)
	    except:
		warn(infile ++ ': line ' + lineno + ': invalid/malformed entry')
		continue
	    cClass = CardClass.toEnum(enum)
	    if cClass is None:
		warn('%s: line %d: unknown card class %r'
		      % (infile, lineno, enum))
	    elif cClass == CardClass.NORMAL_CARD:
		pass
	    elif a in nextMap or a in prevMap:
		warn('%s: card name %r appears more than once' % (infile, a))
	    elif b in nextMap or b in prevMap:
		warn('%s: card name %r appears more than once' % (infile, b))
	    else:
		nextMap[a] = b
		prevMap[b] = a
		classMap[(a,b)] = cClass
	return cls(nextMap, prevMap, classMap)

    def cardClass(self, name):
	if name in self.nextMap:
	    return self.classMap.get((name, self.nextMap[name]), CardClass.NORMAL_CARD)
	elif name in self.prevMap:
	    return self.classMap.get((self.prevMap[name], name), CardClass.NORMAL_CARD)
	else:
	    return CardClass.NORMAL_CARD

    def isPrimary(self,   name): return name in self.nextMap
    def isSecondary(self, name): return name in self.prevMap

    def isSplit(self, name):  return self.cardClass(name) == CardClass.SPLIT_CARD
    def isFlip(self, name):   return self.cardClass(name) == CardClass.FLIP_CARD
    def isDouble(self, name): return self.cardClass(name) == CardClass.DOUBLE_CARD

    def splitLefts(self):
	return sorted(a for ((a,b),c) in self.classMap.items()
			if c == CardClass.SPLIT_CARD)

    def splitRights(self):
	return sorted(b for ((a,b),c) in self.classMap.items()
			if c == CardClass.SPLIT_CARD)

    def flipTops(self):
	return sorted(a for ((a,b),c) in self.classMap.items()
			if c == CardClass.FLIP_CARD)

    def flipBottoms(self):
	return sorted(b for ((a,b),c) in self.classMap.items()
			if c == CardClass.FLIP_CARD)

    def doubleFronts(self):
	return sorted(a for ((a,b),c) in self.classMap.items()
			if c == CardClass.DOUBLE_CARD)

    def doubleBacks(self):
	return sorted(b for ((a,b),c) in self.classMap.items()
			if c == CardClass.DOUBLE_CARD)

    def splits(self):
	return sorted(ab for (ab,c) in self.classMap.items()
				    if c == CardClass.SPLIT_CARD)

    def flips(self):
	return sorted(ab for (ab,c) in self.classMap.items()
				    if c == CardClass.FLIP_CARD)

    def doubles(self):
	return sorted(ab for (ab,c) in self.classMap.items()
				    if c == CardClass.DOUBLE_CARD)

    def alternate(self, name):
	if   name in self.nextMap: return self.nextMap[name]
	elif name in self.prevMap: return self.prevMap[name]
	else: return None


class CardClass(object):
    NORMAL_CARD = 'normal'
    SPLIT_CARD  = 'split'
    FLIP_CARD   = 'flip'
    DOUBLE_CARD = 'double-faced'

    cardClasses = [CardClass.NORMAL_CARD, CardClass.SPLIT_CARD,
		   CardClass.FLIP_CARD,   CardClass.DOUBLE_CARD]

    @staticmethod
    def toEnum(cClass, default=None):
	if cClass is None: return default
	elif cClass.isdigit():
	    # for compatibility with old representation
	    cClass = int(cClass)
	    return CardClass.cardClasses[cClass-1] if 1 <= cClass <= 4
						   else default
	elif re.search(r'^normal(\b|_)', cClass, re.I):
	    return CardClass.NORMAL_CARD
	elif re.search(r'^split(\b|_)',  cClass, re.I):
	    return CardClass.SPLIT_CARD
	elif re.search(r'^flip(\b|_)',   cClass, re.I):
	    return CardClass.FLIP_CARD
	elif re.search(r'^double(\b|_)', cClass, re.I):
	    return CardClass.DOUBLE_CARD
	else:
	    return default

### Shouldn't the below two functions be MultipartDB class methods?
def loadParts(infile=None):  ### Rename "loadMultipartDB"?
    global multiDB
    multiDB = MultipartDB.fromFile(infile)
    return multiDB

def getMultipartDB():
    return MultipartDB({}, {}, {}) if multiDB is None else multiDB

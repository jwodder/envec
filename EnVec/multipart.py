### TODO: Make MultipartDB objects store the name of the file from which they
### were constructed

import re
from warnings import warn
from envec.util import openR, chomp

NORMAL_CARD = 1
SPLIT_CARD  = 2
FLIP_CARD   = 3
DOUBLE_CARD = 4
cardClasses = [NORMAL_CARD, SPLIT_CARD, FLIP_CARD, DOUBLE_CARD]

multiFile = 'data/multipart.tsv'
multiDB = None

class MultipartDB(object):
    @staticmethod
    def fromFile(infile=None):
	if infile is None: infile = multiFile
	fp = openR(infile)
	self = MultipartDB()
	self.nextMap = {}
	self.prevMap = {}
	self.classMap = {}
	lineno = 0
	for line in fp:
	    lineno += 1
	    line = chomp(line)
	    if line.lstrip() == '' or line.lstrip()[0] == '#':
		continue
	    try:
		(a, b, enum) = re.split(r'\t+', line)
	    except:
		warn(infile ++ ': line ' + lineno + ': invalid/malformed entry')
		continue
	    cClass = classEnum(enum)
	    if cClass is None:
		warn('%s: line %d: unknown card class %r'
		      % (infile, lineno, enum))
		continue
	    elif cClass == NORMAL_CARD:
		continue
	    if a in self.nextMap or a in self.prevMap:
		warn('%s: card name %r appears more than once' % (infile, a))
	    elif b in self.nextMap or b in self.prevMap:
		warn('%s: card name %r appears more than once' % (infile, b))
	    else:
		self.nextMap[a] = b
		self.prevMap[b] = a
		self.classMap[(a,b)] = cClass
	fp.close()
	return self

    def cardClass(self, name):
	if name in self.nextMap:
	    return self.classMap.get((name, self.nextMap[name]), NORMAL_CARD)
	elif name in self.prevMap:
	    return self.classMap.get((self.prevMap[name], name), NORMAL_CARD)
	else:
	    return NORMAL_CARD

    def isPrimary(self, name): return name in self.nextMap

    def isSecondary(self, name): return name in self.prevMap

    def isSplit(self, name):  return self.cardClass(name) == SPLIT_CARD
    def isFlip(self, name):   return self.cardClass(name) == FLIP_CARD
    def isDouble(self, name): return self.cardClass(name) == DOUBLE_CARD

    def splitLefts(self):
	return sorted(a for ((a,b),c) in self.classMap.items()
			if c == SPLIT_CARD)

    def splitRights(self):
	return sorted(b for ((a,b),c) in self.classMap.items()
			if c == SPLIT_CARD)

    def flipTops(self):
	return sorted(a for ((a,b),c) in self.classMap.items()
			if c == FLIP_CARD)

    def flipBottoms(self):
	return sorted(b for ((a,b),c) in self.classMap.items()
			if c == FLIP_CARD)

    def doubleFronts(self):
	return sorted(a for ((a,b),c) in self.classMap.items()
			if c == DOUBLE_CARD)

    def doubleBacks(self):
	return sorted(b for ((a,b),c) in self.classMap.items()
			if c == DOUBLE_CARD)

    def splits(self):
	return sorted(ab for (ab,c) in self.classMap.items() if c == SPLIT_CARD)

    def flips(self):
	return sorted(ab for (ab,c) in self.classMap.items() if c == FLIP_CARD)

    def doubles(self):
	return sorted(ab for (ab,c) in self.classMap.items() if c==DOUBLE_CARD)

    def alternate(self, name):
	if name in self.nextMap: return self.nextMap[name]
	elif name in self.prevMap: return self.prevMap[name]
	else: return None

def classEnum(cClass, default=None):
    if cClass is None: return default
    elif cClass.isdigit():
	cClass = int(cClass)
	return cClass if cClass in cardClasses else default
    elif re.search(r'^normal(\b|_)', cClass, re.I): return NORMAL_CARD
    elif re.search(r'^split(\b|_)', cClass, re.I): return SPLIT_CARD
    elif re.search(r'^flip(\b|_)', cClass, re.I): return FLIP_CARD
    elif re.search(r'^double(\b|_)', cClass, re.I): return DOUBLE_CARD
    else: return default

def loadParts(infile=None):
    multiDB = MultipartDB.fromFile(infile)
    return multiDB

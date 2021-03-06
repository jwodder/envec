from   enum     import Enum
import itertools
import json
import warnings
from   ._util   import cheap_repr, for_json

class CardClass(Enum):
    normal       = 1
    split        = 2
    flip         = 3
    double_faced = 4
    BFM          = 5

    def for_json(self):
        return self.name


class MultipartDB:
    DEFAULT_DATAFILE = 'data/multipart.json'

    def __init__(self, infile=None):
        if infile is None:
            infile = open(self.DEFAULT_DATAFILE)
        with infile:
            data = json.load(infile)
        self.sourcefile = infile.name
        self.byName = {}
        self.byClass = {}
        for cclass in CardClass:
            if cclass == CardClass.normal:
                continue
            classed = data.get(cclass.name, [])
            self.byClass[cclass] = classed
            for entry in classed:
                entry["cardClass"] = cclass
                for name in (entry["primary"], entry["secondary"]):
                    if name in self.byName:
                        warnings.warn('%s: name appears more than once in'
                                      ' multipart file; subsequent appearance'
                                      ' ignored' % (name,))
                    else:
                        self.byName[name] = entry

    def cardClass(self, name):
        try:
            entry = self.byName[name]
        except KeyError:
            return CardClass.normal
        else:
            return entry["cardClass"]

    def isPrimary(self, name):
        try:
            return self.byName[name]["primary"] == name
        except KeyError:
            return False

    def isSecondary(self, name):
        try:
            return self.byName[name]["secondary"] == name
        except KeyError:
            return False

    def isSplit(self, name):
        return self.cardClass(name) == CardClass.split

    def isFlip(self, name):
        return self.cardClass(name) == CardClass.flip

    def isDouble(self, name):
        return self.cardClass(name) == CardClass.double_faced

    def isMultipart(self, name):
        return self.cardClass(name) != CardClass.normal

    def primaries(self):
        for entry in self:
            yield entry["primary"]

    def secondaries(self):
        for entry in self:
            yield entry["secondary"]

    def alternate(self, name):
        try:
            entry = self.byName[name]
        except KeyError:
            return None
        else:
            return entry["secondary" if entry["primary"] == name else "primary"]

    def __iter__(self):
        return itertools.chain.from_iterable(self.byClass.values())

    def __len__(self):
        return sum(map(len, self.byClass.values()))

    def __repr__(self):
        return cheap_repr(self)

    def for_json(self):
        return for_json(vars(self), trim=True)

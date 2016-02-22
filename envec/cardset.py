from   functools import total_ordering
import json
import logging
from   ._util    import cheap_repr, for_json

@total_ordering
class CardSet:
    def __init__(self, name, release_date=None, fetch=False, abbreviations=None,
                 **data):
        self.name = name
        self.release_date = release_date
        self.fetch = fetch
        self.abbreviations = abbreviations or {}
        for k,v in data.items():
            setattr(self, k, v)

    def __str__(self):
        return self.name

    def __repr__(self):
        return cheap_repr(self)

    def __eq__(self, other):
        return type(self) is type(other) and vars(self) == vars(other)

    def __le__(self, other):
        # Sets without release dates are sorted after those with dates.
        if type(self) is type(other):
            selfdate = self.release_date
            otherdate = other.release_date
            if (selfdate is None) ^ (otherdate is None):
                return otherdate is None
            elif selfdate != otherdate:
                return selfdate < otherdate
            elif self.name != other.name:
                return self.name < other.name
            else:
                return vars(self) <= vars(other)
        else:
            return NotImplemented

    def for_json(self):
        return for_json(vars(self), trim=True)


class CardSetDB:
    DEFAULT_DATAFILE = 'data/sets.json'

    def __init__(self, infile=None):
        if infile is None:
            infile = open(self.DEFAULT_DATAFILE)
        with infile:
            self.sets = [CardSet(**d) for d in json.load(infile)]
        self.sourcefile = infile.name
        self.byName = {}
        self.byGatherer = {}
        for cs in self.sets:
            if cs.name is None:
                logging.warning('%s: set with unset name', infile.name)
            elif cs.name in self.byName:
                logging.warning('%s: name %r used for more than one set;'
                                ' subsequent appearance ignored',
                                infile.name, cs.name)
            else:
                self.byName[cs.name] = cs
            gath = cs.abbreviations.get("Gatherer")
            if gath is not None:
                if gath in self.byGatherer:
                    logging.warning('%s: Gatherer abbreviation %r already used'
                                    ' for set %r; subsequent use for set %r'
                                    ' ignored',
                                    infile.name, gath,
                                    self.byGatherer[gath].name, cs.name)
                else:
                    self.byGatherer[gath] = cs

    def toFetch(self):
        return filter(lambda s: s.fetch, self.sets)

    def __len__(self):
        return len(self.sets)

    def __iter__(self):
        return iter(self.sets)

    def __repr__(self):
        return cheap_repr(self)

    def for_json(self):
        return for_json(vars(self), trim=True)

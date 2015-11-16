from __future__ import unicode_literals
from functools  import total_ordering
from string     import ascii_lowercase
from .multival  import Multival
from ._util     import txt2xml, cheap_repr

multival = set("number artist flavor watermark multiverseid notes".split())

@total_ordering
class Printing(object):
    def __init__(self, set, rarity=None, number=None, artist=None, flavor=None,
                 watermark=None, multiverseid=None, notes=None):
        self.set = set
        self.rarity = rarity
        self.number = Multival(number)
        self.artist = Multival(artist)
        self.flavor = Multival(flavor)
        self.watermark = Multival(watermark)
        self.multiverseid = Multival(multiverseid)
        self.notes = Multival(notes)

    def __setattr__(self, key, value):
        if key in multival:
            value = Multival(value)
        self.__dict__[key] = value

    def copy(self):
        return self.__class__(**vars(self))

    def toXML(self):
        txt = "  <printing>\n   <set>" + txt2xml(self.set) + "</set>\n"
        if self.rarity:
            txt += "   <rarity>" + txt2xml(self.rarity.name) + "</rarity>\n"
        for attr in multival:
            txt += getattr(self, attr).toXML(attr, attr in ('flavor', 'notes'))
        txt += "  </printing>\n"
        return txt

    def effectiveNum(self):
        nums = self.number.all()
        if not nums:
            return None
        elif len(nums) == 1:
            return int(nums[0])
        else:
            return sorted(int(n.rstrip(ascii_lowercase)) for n in nums)[0]

    @classmethod
    def fromDict(cls, obj):
        if isinstance(obj, cls):
            return obj.copy()
        else:
            return cls(**obj)

    def __eq__(self, other):
        return type(self) is type(other) and vars(self) == vars(other)

    def __le__(self, other):
        if type(self) is type(other):
            return (self.set,  self.multiverseid.all()[0]) \
                 < (other.set, other.multiverseid.all()[0])
        else:
            return NotImplemented

    def __repr__(self):
        return cheap_repr(self)

    def jsonable(self):
        return vars(self)

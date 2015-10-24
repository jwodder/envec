from string    import ascii_lowercase
from warnings  import warn
from .multival import Multival
from ._util    import txt2xml

multival = "number artist flavor watermark multiverseid notes".split()

def multivalProp(field):
    def getter(self): return getattr(self, field)
    def setter(self, val): setattr(self, field, Multival(val))
    return property(getter, setter)

class Printing(object):
    __slots__ = ("set",           # str (required)
                 "rarity",        # str or None
                 "_number",       # Multival
                 "_artist",       # Multival
                 "_flavor",       # Multival
                 "_watermark",    # Multival
                 "_multiverseid", # Multival
                 "_notes")        # Multival

    def __init__(self, set, rarity=None, number=None, artist=None, flavor=None,
                 watermark=None, multiverseid=None, notes=None):
        self.set = set
        self.rarity = rarity
        self._number = Multival(number)
        self._artist = Multival(artist)
        self._flavor = Multival(flavor)
        self._watermark = Multival(watermark)
        self._multiverseid = Multival(multiverseid)
        self._notes = Multival(notes)

    number       = multivalProp("_number")
    artist       = multivalProp("_artist")
    flavor       = multivalProp("_flavor")
    watermark    = multivalProp("_watermark")
    multiverseid = multivalProp("_multiverseid")
    notes        = multivalProp("_notes")

    def copy(self):
        return self.__class__(**((attr, getattr(self, attr))
                                 for attr in self.__slots__))

    def toXML(self):
        txt = "  <printing>\n   <set>" + txt2xml(self.set) + "</set>\n"
        if self.rarity:
            txt += "   <rarity>" + txt2xml(self.rarity) + "</rarity>\n"
        for attr in multival:
            txt += getattr(self, attr).toXML(attr, attr in ('flavor', 'notes'))
        txt += "  </printing>\n"
        return txt

    def effectiveNum(self):
        nums = self.number.all()
        if not nums: return None
        elif len(nums) == 1: return int(nums[0])
        else: return sorted(int(n.rstrip(ascii_lowercase)) for n in nums)[0]

    @classmethod
    def fromDict(cls, obj):  # called `fromHashref` in the Perl version
        if isinstance(obj, cls): return obj.copy()
        else: return cls(**obj)

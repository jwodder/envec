import copy
from   functools  import total_ordering
from   string     import ascii_lowercase
from   .cardset   import CardSet
from   .multival  import Multival
from   .rarity    import Rarity
from   ._util     import cheap_repr, cleanDict

multival = "number artist flavor watermark multiverseid notes".split()

@total_ordering
class Printing:
    def __init__(self, set, rarity=None, number=None, artist=None, flavor=None,
                 watermark=None, multiverseid=None, notes=None):
        self.set = CardSet(**set) if isinstance(set, dict) else set
        self.rarity = rarity if isinstance(rarity, Rarity) \
                             else Rarity.fromString(rarity)
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

    def effectiveNum(self):
        nums = self.number.all()
        if not nums:
            return None
        elif len(nums) == 1:
            return nums[0]
        else:
            return min(int(str(n).rstrip(ascii_lowercase)) for n in nums)

    @classmethod
    def fromDict(cls, obj):
        if isinstance(obj, cls):
            return copy.deepcopy(obj)
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
        data = vars(self).copy()
        for field in multival:
            data[field] = data[field].jsonable()
        return cleanDict(data)

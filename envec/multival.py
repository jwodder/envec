# Class for properties of card printings that can vary between different
# subcards of a multipart (split, flip, double-faced) card

# The .val attribute of each Multival object is a list of lists of scalars
# in which the sublist at index 0 contains the card-wide values, the sublist at
# index 1 contains the values for subcard 0, index 2 is for subcard 1, etc.
# None of these lists should ever contain empty strings or values that are
# neither strings nor integers.

from ._util import cheap_repr

class Multival:
    def __init__(self, val):
        if val is None or val == '':
            self.val = []
        elif isinstance(val, (str, int)):
            self.val = [[val]]
        elif isinstance(val, list):
            self.val = []
            undef = 0
            for elem in val:
                if elem is None or elem == '':
                    undef += 1
                elif isinstance(elem, list):
                    elems = []
                    for e in elem:
                        if isinstance(e, (str, int)) and e != '':
                            elems.append(e)
                        else:
                            raise TypeError("Elements of sublists must be nonempty strings or integers")
                    if elems:
                        self.val.extend([[]] * undef + [elems])
                        undef = 0
                    else:
                        undef += 1
                elif isinstance(elem, (str, int)):
                    self.val.extend([[]] * undef + [elem])
                    undef = 0
                else:
                    raise TypeError("List elements must be strings, integers, array references, or undef")
        elif isinstance(val, Multival):
            self.val = [v[:] for v in val.val]
        else:
            raise TypeError("Multival constructors must be strings, integers, array references, or undef")

    def all(self):
        # Returns all defined values in the Multival
        return [w for v in self.val for w in v]

    def __bool__(self):
        return bool(self.val)

    def get(self, i=-1):
        if not self.val:
            return []
        if i < 0:
            i += 1
        return self.val[i] if 0 <= i < len(self.val) else []

    def asArray(self):
        return [v[:] for v in self.val]

    def mapvals(self, function):
        return Multival([list(map(function, v)) for v in self.val])

    def __repr__(self):
        return cheap_repr(self)

    def for_json(self):
        return self.val

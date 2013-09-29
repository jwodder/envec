# Class for properties of card printings that can vary between different
# subcards of a multipart (split, flip, double-faced) card

# The .val attribute of each Multival object is a list of lists of strings
# in which the sublist at index 0 contains the card-wide values, the sublist at
# index 1 contains the values for subcard 0, index 2 is for subcard 1, etc.
# None of these lists should ever contain empty strings, None, or non-string
# values.

from envec.util import jsonify, sym2xml, txt2xml

class Multival(object):
    def __init__(self, val):
	if val is None or val == '': self.val = []
	elif isinstance(val, str): self.val = [[val]]
	elif isinstance(val, list):
	    self.val = []
	    undef = 0
	    for elem in val:
		if elem is None or elem == '': undef += 1
		elif isinstance(elem, list):
		    elems = []
		    for e in elem:
			if isinstance(e, str) and e != '': elems.append(e)
			else: raise TypeError("Elements of sublists must be nonempty strings")
		    if elems:
			self.val.extend([[]] * undef + [elems])
			undef = 0
		    else: undef += 1
		elif isinstance(elem, str):
		    self.val.extend([[]] * undef + [elem])
		    undef = 0
		else:
		    raise TypeError("List elements must be strings, array references, or undef")
		    undef += 1
	elif isinstance(val, Multival): self.val = [v[:] for v in val.val]
	else: raise TypeError("Multival constructors must be strings, array references, or undef")

    def all(self): return [w for v in self.val for w in v]
     # Returns all defined values in the Multival

    def any(self): return bool(self.val)

    def get(self, i=-1):
	if not self.val: return []
	if i < 0: i += 1
	return self.val[i] if 0 <= i < len(self.val) else []

    def copy(self): return Multival(self)

    def asArray(self): return [v[:] for v in self.val]

    def toJSON(self): return jsonify(self.val)

    def toXML(self, name, sym):
	if not name: name = 'MULTIVAL'  # Just in case
	txt = ''
	i = -1
	for sub in self.val:
	    attr = '' if i == -1 else ' subcard="%d"' % (i,)
	    for s in sub:
		txt += '   <%s%s>%s</%s>\n' \
		      % (name, attr, sym2xml(s) if sym else txt2xml(s), name)
	    i += 1
	return txt

    def mapvals(self, function):
	return Multival([map(function, v) for v in self.val])

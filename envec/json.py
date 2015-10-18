import json
import sys
from .card  import Card
from ._util import openR

def dumpArray(array, fh=None):
    if fh is None: fh = sys.stdout
    fh.write("[\n")
    first = True
    for c in array:
        if first: fh.write(",\n\n")
        fh.write(c.toJSON())
        first = False
    fh.write("\n]\n")

def parseJSON(s):  # Load from a string
    data = json.loads(s)
    if isinstance(data, list):
        return map(Card.fromDict, data)
    else:
        raise ValueError('Root JSON structure must be an array')

def loadJSON(fname=None):  # Load from a file (identified by name) or stdin
    fh = openR(fname)
    data = json.load(fh)
    if isinstance(data, list):
        return map(Card.fromDict, data)
    else:
        raise ValueError('Root JSON structure must be an array')

import json
from   enum      import Enum
import ijson
from   six.moves import map
from   .card     import Card
from   .multival import Multival

class EnVecEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Enum):
            return obj.name
        elif isinstance(obj, Multival):
            return obj.val
        try:
            data = vars(obj)
        except TypeError:
            return super(EnVecEncoder, self).default(obj)
        return {k:v for k,v in data.iteritems() if v is not None and v != ''}

def iloadJSON(fp):
    with fp:
        return map(Card.fromDict, ijson.items(fp, 'cards.item'))

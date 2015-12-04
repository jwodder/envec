import json
import ijson
from   .card import Card

class EnVecEncoder(json.JSONEncoder):
    def default(self, obj):
        try:
            return obj.jsonable()
        except AttributeError:
            return super(EnVecEncoder, self).default(obj)

def iloadJSON(fp):
    return map(Card.fromDict, ijson.items(fp, 'cards.item'))

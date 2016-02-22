import json
import ijson
from   .card import Card

class EnVecEncoder(json.JSONEncoder):
    def default(self, obj):
        if hasattr(obj, 'for_json'):
            return obj.for_json()
        else:
            return super(EnVecEncoder, self).default(obj)

def iloadJSON(fp):
    return map(Card.fromDict, ijson.items(fp, 'cards.item'))

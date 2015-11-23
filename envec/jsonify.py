import json
import ijson
from   .card import Card

class EnVecEncoder(json.JSONEncoder):
    def default(self, obj):
        try:
            data = obj.jsonable()
        except AttributeError:
            return super(EnVecEncoder, self).default(obj)
        if isinstance(data, dict):
            return {k:v for k,v in data.items()
                        if v is not None and v != ''}
        else:
            return data

def iloadJSON(fp):
    return map(Card.fromDict, ijson.items(fp, 'cards.item'))

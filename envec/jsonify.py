import json
from   .multival import Multival

class EnVecEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Multival):
            return self.val
        try:
            data = vars(obj)
        except TypeError:
            return super(EnVecEncoder, self).default(obj)
        return {k:v for k,v in data.iteritems() if v is not None and v != ''}

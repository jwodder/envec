from enum import Enum

class Rarity(Enum):
    land        = ('L', 'Land')
    L           = ('L', 'Land')

    common      = ('C', 'Common')
    C           = ('C', 'Common')

    uncommon    = ('U', 'Uncommon')
    U           = ('U', 'Uncommon')

    rare        = ('R', 'Rare')
    R           = ('R', 'Rare')

    mythic_rare = ('M', 'Mythic Rare')
    M           = ('M', 'Mythic Rare')
    MR          = ('M', 'Mythic Rare')
    mythic      = ('M', 'Mythic Rare')
    mythicrare  = ('M', 'Mythic Rare')

    special     = ('S', 'Special')
    S           = ('S', 'Special')

    bonus       = ('B', 'Bonus')
    B           = ('B', 'Bonus')

    promo       = ('P', 'Promo')
    P           = ('P', 'Promo')
    promotional = ('P', 'Promo')

    def __init__(self, shortname, longname):
        self.shortname = shortname
        self.longname  = longname

    @classmethod
    def fromString(cls, name):
        if isinstance(name, cls):
            return name
        name = name.replace('-', '_')
        if len(name) <= 2:
            return cls[name.upper()]
        else:
            return cls[name.lower()]

    def for_json(self):
        return self.name

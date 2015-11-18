from collections import defaultdict
from .card       import Card
from .content    import Content
from .multival   import Multival
from .printing   import Printing
from .multipart  import CardClass
from ._util      import parseTypes, simplify

def joinCards(format, part1, part2):
    return Card(cardClass=format,
                content= part1.content + part2.content,
                printings = joinPrintings(part1.name + ' // ' + part2.name,
                                          part1.printings, part2.printings),
                rulings = joinRulings(part1.rulings, part2.rulings))

def unmungFlip(flip):
    if flip.isMultipart():
        return flip
    # Should a warning be given if `flip` isn't actually a munged flip card?
    texts = (flip.text or '').split("\n----\n", 1)
    if len(texts) < 2:
        return flip
    lines = texts[1].splitlines()
    (name, type_, pt, txt) = (lines[0], lines[1], lines[2], lines[3:])
    (supers, types, subs) = parseTypes(type_)
    (power, toughness) = map(simplify, pt.split('/', 1)) if pt else (None, None)
    bottom = Content(name=name, cost=flip.cost, supertypes=supers, types=types,
                     subtypes=subs, power=power, toughness=toughness,
                     text="\n".join(txt))
    top = flip.part1
    top.text = texts[0]
    return Card(cardClass=CardClass.flip, content=[top, bottom],
                printings=flip.printings, rulings=flip.rulings)

def joinPrintings(name, prnt1, prnt2):
    ### FRAGILE ASSUMPTIONS:
    ### - joinPrintings will only ever be called to join data freshly scraped
    ###   from Gatherer.
    ### - The data will always contain no more than one value in each Multival
    ###   field.
    ### - Such values will always be in the card-wide slot.
    ### - The split cards from the Invasion blocks are the only cards that need
    ###   to be joined that have more than one printing per set, and these
    ###   duplicate printings differ only in multiverseid.
    ### - The rarity field of part 1 is always valid for the whole card.
    prnts1 = defaultdict(list)
    prnts2 = defaultdict(list)
    for p in prnt1:
        prnts1[p.set].append(p)
    for p in prnt2:
        prnts2[p.set].append(p)
    joined = []
    for set_ in prnts1:
        if set_ not in prnts2:
            raise ValueError("set mismatch for %r: part 1 has a printing in %s but part 2 does not" % (name, set_))
        ### TODO: Also check for sets that part 2 has but part 1 doesn't?
        if len(prnts1[set_]) != len(prnts2[set_]):
            raise ValueError("printings mismatch for %r in %s: part 1 has %d printings but part 2 has %d" % (name, set_, len(prnts1[set_]), len(prnts2[set_])))
        if len(prnts1[set_]) > 1:
            multiverse = Multival([sorted(v for p in prnts1[set_]
                                            for v in p.multiverseid.all())])
        else:
            multiverse = None
        p1 = prnts1[set_][0]
        p2 = prnts2[set_][0]
        prnt = {"set": set_, "rarity": p1.rarity}
        for field in ["number", "artist", "flavor", "watermark", "multiverseid",
                      "notes"]:
            val1 = getattr(p1, field).get()
            val1 = val1[0] if val1 else None
            val2 = getattr(p2, field).get()
            val2 = val2[0] if val2 else None
            valM = None
            if val1 is not None or val2 is not None:
                if val1 is None:
                    valM = [[], [], [val2]]
                elif val2 is None:
                    valM = [[], [val1]]
                elif val1 != val2:
                    valM = [[], [val1], [val2]]
                else:
                    valM = getattr(p1, field)
            prnt[field] = Multival(valM)
        if multiverse is not None:
            prnt["multiverseid"] = multiverse
        joined.append(Printing(**prnt))
    joined.sort()
    return joined

def joinRulings(rules1, rules2):
    # This assumes that the rulings in `rules1` and `rules2` only have 'date'
    # and 'ruling' fields.
    if rules1 is None:
        rules1 = []
    if rules2 is None:
        rules2 = []
    # The above two lines are unnecessary in the Python version, right?
    rulings = []
    for r1 in rules1:
        try:
            rules2.remove(r1)
        except ValueError:
            r1b = r1.copy()
            r1b["subcard"] = 0
            rulings.append(r1b)
        else:
            rulings.append(r1.copy())
    for r2 in rules2:
        r2b = r2.copy()
        r2b["subcard"] = 1
        rulings.append(r2b)
    return rulings

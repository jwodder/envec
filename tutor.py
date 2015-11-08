#!/usr/bin/python
"""
Tasks this script takes care of:
 - Remove italics from flavor text and watermarks
 - Convert short set names to long set names
 - Convert rarities from single characters to full words
 - Tag split, flip, and double-faced cards as such
 - Unmung munged flip cards
 - For the Ascendant/Essence cycle, remove the P/T values from the bottom
   halves

Things this script still needs to do:
 - Incorporate data/rarities.tsv (adding an "old-rarity" field to Printing.pm)
 - Make sure nothing from data/tokens.txt (primarily the Unglued tokens)
   slipped through
 - Somehow handle split cards with differing artists for each half
"""

from   __future__  import print_function
import argparse
from   collections import defaultdict
from   datetime    import datetime
import json
import re
import requests
import sys
from   time        import time
import envec
import envec._util as util

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('-C', '--card-ids', type=argparse.FileType('r'))
    parser.add_argument('-S', '--set-file', type=argparse.FileType('r'))
    parser.add_argument('-j', '--json-out', type=argparse.FileType('w', 0),
                                            default='details.json')
    parser.add_argument('-x', '--xml-out', type=argparse.FileType('w', 0),
                                           default='details.xml')
    parser.add_argument('-l', '--logfile', type=argparse.FileType('w', 0),
                                           default=sys.stderr)
    parser.add_argument('-i', '--idfile', type=argparse.FileType('w'))
    parser.add_argument('-I', '--idfile2', type=argparse.FileType('w'))
    args = parser.parse_args()

    missed = []
    setdb = envec.CardSetDB(args.set_file)
    multidb = envec.MultipartDB()

    def logmsg(*args):
        print(time(), ' ', *args, sep='', file=args.logfile)

    def ending():
        if missed:
            try:
                misfile = open('missed.txt', 'w')
            except IOError as e:
                logmsg("ERROR: Could not write to missed.txt: ", str(e))
                for m in missed:
                    logmsg("MISSED: ", m)
            else:
                with misfile:
                    for m in missed:
                        print(m, file=misfile)
            logmsg("INFO: Failed to fetch ", len(missed), " item",
                   's' if len(missed) > 1 else '')
            logmsg("DONE")
            sys.exit(1)
        else:
            logmsg('DONE')
            sys.exit(0)

    cardIDs = {}
    if args.card_ids:
        with args.card_ids:
            for line in card_ids:
                line = line.strip()
                if not line or line[0] == '#':
                    continue
                card, cid = re.search(r'^([^\t]+)\t+([^\t]+)', line).groups()
                cardIDs.setdefault(card, int(cid))
    else:
        for cardset in setdb.toFetch():
            logmsg("FETCHING SET " + str(cardset))
            r = requests.get('http://gatherer.wizards.com/Pages/Search/Default.aspx', params={
                "output": "checklist",
                "action": "advanced",
                "set": '["' + str(cardset) + '"]',
                "special": "true",
            })
            if r.status_code < 400:
                cards = envec.parseChecklist(r.text)
                if cards:
                    for c in cards:
                        cardIDs.setdefault(c.name, c.multiverseid)
                else:
                    logmsg("ERROR: No cards in set " + str(cardset) + "???")
            else:
                logmsg("ERROR: Could not fetch set " + str(cardset))
                ### Log r.status_code, r.reason, and/or r.text
                missed.append("SET " + str(cardset))

    logmsg("INFO: ", len(cardIDs), " card names imported")
    for c in multidb.secondaries():
        del cardIDs[c]
    logmsg("INFO: ", len(cardIDs), " cards to fetch")

    if args.idfile or args.idfile2:
        out = args.idfile2 or args.idfile
        with out:
            for k in sorted(cardIDs):
                print(k, '\t', cardIDs[k], sep='', file=out)
        logmsg("INFO: Card IDs written to " + out.name)
        if args.idfile2:
            ending()

    print('[', file=args.json_out)

    print('<?xml version="1.0" encoding="UTF-8"?>', file=args.xml_out)
    #print('<!DOCTYPE cardlist SYSTEM "mtgcard.dtd">', file=args.xml_out)
    print('<cardlist date="', datetime.utcfromtimestamp(time()).strftime('%Y-%m-%dT%H:%M:%SZ'), '">', sep='', file=args.xml_out)
    print('', file=args.xml_out)

    logmsg("INFO: Fetching individual card data...")
    first = True
    for name in sorted(cardIDs):
        if first:
            first = False
        else:
            print(',', file=args.json_out)
            print('', file=args.json_out)
        ids = [cardIDs[name]]
        seen = set()
        card = None
        printings = []
        while ids:
            id_ = ids.pop(0)
            idstr = name + '/' + str(id_)
            logmsg("FETCHING CARD ", idstr)
            params = {"multiverseid": str(id_)}
            if multidb.isSplit(name):
                params["part"] = name
            # As of 2013 July 10, despite the fact that split cards in Gatherer
            # now have both halves on a single page like flip & double-faced
            # cards, you still need to append "&part=$name" to the end of their
            # URLs or else the page may non-deterministically display the
            # halves in the wrong order.
            r = requests.get('http://gatherer.wizards.com/Pages/Card/Details.aspx', params=params)
            if r.status_code >= 400:
                logmsg("ERROR: Could not fetch card ", idstr)
                missed.append("CARD " + idstr)
                first = True  # to suppress extra commas
                continue
            prnt = envec.parseDetails(r.text)
            ### TODO: This needs to detect flip & double-faced cards that are
            ### missing parts.
            if multidb.isSplit(name):
                prnt.cardClass = envec.CardClass.split
            elif multidb.isFlip(name):
                if re.search(r'^----$', prnt.text or '', flags=re.M):
                    prnt = envec.unmungFlip(prnt)
                else:
                    prnt.cardClass = envec.CardClass.flip
                    # Manually fix some flip card entries that Gatherer just
                    # can't seem to get right:
                    if re.search(r'^[^\s,]+, \w+ Ascendant$', prnt.part1.name):
                        prnt.part2.pow = None
                        prnt.part2.tough = None
            elif multidb.isDouble(name):
                prnt.cardClass = envec.CardClass.double
            if card is None:
                card = prnt
            ### When `card` is non-None, check that it equals `prnt`?
            if not seen:
                seen.add(id_)
                if multidb.isSplit(name) or multidb.isDouble(name) or \
                        name == 'B.F.M. (Big Furry Monster)':
                    # Split cards, DFCs, and B.F.M. have separate multiverseids
                    # for each component, so here we're going to assume for
                    # each such card that if you've seen any IDs for one set,
                    # you've seen them all for that set, and if you haven't
                    # seen any for a set, you'll still only get to see one.
                    setIDs = defaultdict(list)
                    for p in prnt.printings:
                        setIDs[p.set].extend(p.multiverseid.all())
                    for cset, idlist in setIDs.iteritems():
                        if id_ in idlist:
                            setIDs[cset] = []
                        elif idlist:
                            setIDs[cset] = [idlist[0]]
                    newIDs = sum(setIDs.itervalues(), [])
                else:
                    newIDs = sum((p.multiverseid.all() for p in prnt.printings), [])
                for nid in newIDs:
                    if nid not in seen:
                        ids.append(nid)
                        seen.add(nid)
            ### Assume that the printing currently being fetched is the only one
            ### that has an "artist" field: (Try to make this more robust?)
            for p in prnt.printings:
                if p.artist.any():
                    newPrnt = p
                    break
            try:
                newPrnt.set = setdb.byGatherer[newPrnt.set]
            except KeyError:
                logmsg('ERROR: Unknown set "', newPrnt.set, '" for ', idstr)
            if newPrnt.rarity is not None:
                try:
                    newPrnt.rarity = envec.Rarity.fromString(newPrnt.rarity)
                except KeyError:
                    logmsg('ERROR: Unknown rarity "', newPrnt.rarity, '" for ',
                           idstr)
            newPrnt.flavor = newPrnt.flavor.mapvals(rmitalics)
            newPrnt.watermark = newPrnt.watermark.mapvals(rmitalics)
            printings.append(newPrnt)

        if card is not None:  # in case no printings can be fetched
            card.printings = sortPrintings(printings)
            js = json.dumps(card, cls=envec.EnVecEncoder, sort_keys=True,
                                  indent=4, separators=(',', ': '))
            print(re.sub('^', '    ', js, flags=re.M), end='', file=args.json_out)
            print(card.toXML(), file=args.xml_out)

    print('\n]', file=args.json_out)
    print('</cardlist>', file=args.xml_out)
    ending()

def rmitalics(s):
    return re.sub(r'<i>\s*|\s*</i>', '', s, flags=re.I)

if __name__ == '__main__':
    main()

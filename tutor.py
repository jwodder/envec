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
import codecs
from   collections import defaultdict
from   datetime    import datetime
import io
import json
import logging
import re
import sys
from   time        import time
import requests
import envec

datefmt = '%Y-%m-%dT%H:%M:%SZ'

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

    ### TODO: Figure out a better/more Pythonic way to accomplish this:
    reader = codecs.getreader('utf-8')
    writer = codecs.getwriter('utf-8')
    if args.card_ids is not None:
        args.card_ids = reader(args.card_ids)
    if args.set_file is not None:
        args.set_file = reader(args.set_file)
    args.json_out = writer(args.json_out)
    args.xml_out = writer(args.xml_out)
    args.logfile = writer(args.logfile)
    if args.idfile is not None:
        args.idfile = writer(args.idfile)
    if args.idfile2 is not None:
        args.idfile2 = writer(args.idfile2)

    logging.basicConfig(format='%(asctime)s %(levelname)s %(message)s',
                        level=logging.INFO, datefmt=datefmt,
                        stream=args.logfile)

    missed = []
    setdb = envec.CardSetDB(args.set_file)
    multidb = envec.MultipartDB()

    with requests.Session() as s:
        cardIDs = {}
        if args.card_ids:
            with args.card_ids:
                for line in args.card_ids:
                    line = line.strip()
                    if not line or line[0] == '#':
                        continue
                    card, cid = re.search(r'^([^\t]+)\t+([^\t]+)', line)\
                                  .groups()
                    cardIDs.setdefault(card, int(cid))
        else:
            for cardset in setdb.toFetch():
                logging.info('Fetching set %r', str(cardset))
                try:
                    cards = list(envec.fetch_checklist(cardset, session=s))
                except Exception:
                    logging.exception('Could not fetch set %r', str(cardset))
                    missed.append("SET " + str(cardset))
                else:
                    if cards:
                        for c in cards:
                            cardIDs.setdefault(c["name"], c["multiverseid"])
                    else:
                        logging.warning('No cards in set %r???', str(cardset))

        logging.info('%d card names imported', len(cardIDs))
        for c in multidb.secondaries():
            cardIDs.pop(c, None)
        logging.info('%d cards to fetch', len(cardIDs))

        if args.idfile or args.idfile2:
            out = args.idfile2 or args.idfile
            with out:
                for k in sorted(cardIDs):
                    print(k, '\t', cardIDs[k], sep='', file=out)
            logging.info('Card IDs written to %r', out.name)
            if args.idfile2:
                ending(missed)

        timestamp = datetime.utcfromtimestamp(time()).strftime(datefmt)

        print('{"date": "%s", "cards": [' % (timestamp,), file=args.json_out)

        print('<?xml version="1.0" encoding="UTF-8"?>', file=args.xml_out)
        #print('<!DOCTYPE cardlist SYSTEM "mtgcard.dtd">', file=args.xml_out)
        print('<cardlist date="%s">' % (timestamp,), file=args.xml_out)
        print('', file=args.xml_out)

        logging.info('Fetching individual card data...')
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
                logging.info('Fetching card %s', idstr)
                params = {"multiverseid": id_}
                if multidb.isSplit(name):
                    params["part"] = name
                # As of 2013 July 10, despite the fact that split cards in
                # Gatherer now have both halves on a single page like flip &
                # double-faced cards, you still need to append "&part=$name" to
                # the end of their URLs or else the page may
                # non-deterministically display the halves in the wrong order.
                r = s.get('http://gatherer.wizards.com/Pages/Card/Details.aspx',
                          params=params)
                if r.status_code >= 400:
                    logging.error('Could not fetch card %s: %d %s', idstr,
                                  r.status_code, r.reason)
                    missed.append('CARD ' + idstr)
                    first = True  # to suppress extra commas
                    continue
                prnt = envec.parse_details(r.text)
                ### TODO: This needs to detect flip & double-faced cards that
                ### are missing parts.
                if multidb.isSplit(name):
                    prnt.cardClass = envec.CardClass.split
                elif multidb.isFlip(name):
                    if re.search(r'^----$', prnt.text or '', flags=re.M):
                        prnt = envec.unmungFlip(prnt)
                    else:
                        prnt.cardClass = envec.CardClass.flip
                        # Manually fix some flip card entries that Gatherer
                        # just can't seem to get right:
                        if re.search(r'^[^\s,]+, \w+ Ascendant$',
                                     prnt.part1.name):
                            prnt.part2.power = None
                            prnt.part2.toughness = None
                elif multidb.isDouble(name):
                    prnt.cardClass = envec.CardClass.double_faced
                if card is None:
                    card = prnt
                ### TODO: When `card` is non-None, check that it equals `prnt`?
                if not seen:
                    seen.add(id_)
                    if multidb.isSplit(name) or multidb.isDouble(name) or \
                            name == 'B.F.M. (Big Furry Monster)':
                        # Split cards, DFCs, and B.F.M. have separate
                        # multiverseids for each component, so here we're going
                        # to assume for each such card that if you've seen any
                        # IDs for one set, you've seen them all for that set,
                        # and if you haven't seen any for a set, you'll still
                        # only get to see one.
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
                        newIDs = sum((p.multiverseid.all()
                                      for p in prnt.printings), [])
                    for nid in newIDs:
                        if nid not in seen:
                            ids.append(nid)
                            seen.add(nid)
                ### Assume that the printing currently being fetched is the
                ### only one that has an "artist" field: (TODO: Try to make
                ### this more robust)
                for p in prnt.printings:
                    if p.artist:
                        newPrnt = p
                        break
                try:
                    newPrnt.set = setdb.byGatherer[newPrnt.set]
                except KeyError:
                    logging.error('Unknown set %r for %s', newPrnt.set, idstr)
                if newPrnt.rarity is not None:
                    try:
                        newPrnt.rarity = envec.Rarity.fromString(newPrnt.rarity)
                    except KeyError:
                        logging.error('Unknown rarity %r for %s',
                                      newPrnt.rarity, idstr)
                newPrnt.flavor = newPrnt.flavor.mapvals(rmitalics)
                newPrnt.watermark = newPrnt.watermark.mapvals(rmitalics)
                printings.append(newPrnt)
            if card is not None:  # in case no printings can be fetched
                printings.sort()
                card.printings = printings
                js = json.dumps(card, cls=envec.EnVecEncoder, sort_keys=True,
                                      indent=4, separators=(',', ': '))
                print(re.sub('^', '    ', js, flags=re.M), end='',
                      file=args.json_out)
                print(card.toXML(), file=args.xml_out)

    print('\n]}', file=args.json_out)
    print('</cardlist>', file=args.xml_out)
    ending(missed)

def rmitalics(s):
    return re.sub(r'<i>\s*|\s*</i>', '', s, flags=re.I)

def ending(missed):
    if missed:
        try:
            misfile = io.open('missed.txt', 'wt', encoding='utf-8')
        except IOError:
            logging.exception('Could not write to missed.txt')
            for m in missed:
                logging.info('MISSED: %s', m)
        else:
            with misfile:
                for m in missed:
                    print(m, file=misfile)
        logging.info('Failed to fetch %d item%s', len(missed),
                     's' if len(missed) > 1 else '')
        logging.info('Done.')
        sys.exit(1)
    else:
        logging.info('Done.')
        sys.exit(0)

if __name__ == '__main__':
    main()

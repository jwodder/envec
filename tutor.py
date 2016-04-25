#!/usr/bin/python3
"""
Tasks this script takes care of:
 - Convert short set names to long set names
 - Tag split, flip, and double-faced cards as such
 - Unmung munged flip cards
 - For the Ascendant/Essence cycle, remove the P/T values from the bottom
   halves
"""

import argparse
from   collections import defaultdict
import json
import logging
import re
import sys
import time
import envec

datefmt = '%Y-%m-%dT%H:%M:%SZ'

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('-S', '--set-file',
                        type=argparse.FileType('r', encoding='utf-8'))
    parser.add_argument('-o', '--outfile',
                        type=argparse.FileType('w', encoding='utf-8'))
    parser.add_argument('-l', '--logfile', default=sys.stderr,
                        type=argparse.FileType('w', encoding='utf-8'))
    parser.add_argument('-i', '--ids', metavar='IDFILE',
                        type=argparse.FileType('r', encoding='utf-8'))
    parser.add_argument('-I', '--write-ids', metavar='IDFILE',
                        type=argparse.FileType('w', encoding='utf-8'))
    args = parser.parse_args()

    logging.basicConfig(format='%(asctime)s %(levelname)s %(message)s',
                        level=logging.INFO, datefmt=datefmt,
                        stream=args.logfile)
    logging.captureWarnings(True)

    missed = []
    setdb = envec.CardSetDB(args.set_file)
    multidb = envec.MultipartDB()

    if args.outfile is None:
        latest = max(filter(lambda s: s.release_date is not None and \
                                      s.abbreviations.get("Gatherer") \
                                        is not None, setdb)) 
        outname = time.strftime('%Y%m%d', time.gmtime()) + '-' + \
            latest.abbreviations["Gatherer"] + '.json'
        args.outfile = open(outname, 'w', encoding='utf-8')

    with envec.Tutor() as t:
        cardIDs = {}
        if args.ids:
            with args.ids:
                for line in args.ids:
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
                    cards = list(t.fetch_checklist(cardset))
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

        if args.write_ids:
            with args.write_ids:
                for k in sorted(cardIDs):
                    print(k, cardIDs[k], sep='\t', file=args.write_ids)
            logging.info('Card IDs written to %r', args.write_ids.name)
            ending(missed)

        timestamp = time.strftime(datefmt, time.gmtime())

        print('{"date": "%s", "cards": [' % (timestamp,), file=args.outfile)

        logging.info('Fetching individual card data...')
        first = True
        for name in sorted(cardIDs):
            if first:
                first = False
            else:
                print(',', file=args.outfile)
                print('', file=args.outfile)
            ids = [cardIDs[name]]
            seen = set()
            card = None
            printings = []
            while ids:
                id_ = ids.pop(0)
                idstr = name + '/' + str(id_)
                logging.info('Fetching card %s', idstr)
                try:
                    prnt = t.fetch_details(id_, name if multidb.isSplit(name)
                                                     else None)
                    # As of 2013 July 10, despite the fact that split cards in
                    # Gatherer now have both halves on a single page like flip
                    # & double-faced cards, you still need to append
                    # "&part=$name" to the end of their URLs or else the page
                    # may non-deterministically display the halves in the wrong
                    # order.
                except Exception:
                    logging.exception('Could not fetch card %s', idstr)
                    missed.append('CARD ' + idstr)
                    first = True  # to suppress extra commas
                    continue
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
                        for cset, idlist in setIDs.items():
                            if id_ in idlist:
                                setIDs[cset] = []
                            elif idlist:
                                setIDs[cset] = [idlist[0]]
                        newIDs = sum(setIDs.values(), [])
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
                printings.append(newPrnt)
            if card is not None:  # in case no printings can be fetched
                printings.sort()
                card.printings = printings
                js = json.dumps(card, cls=envec.EnVecEncoder, sort_keys=True,
                                      indent='    ', ensure_ascii=False)
                print(re.sub('^', '    ', js, flags=re.M), end='',
                      file=args.outfile)

    print('\n]}', file=args.outfile)
    ending(missed)

def ending(missed):
    if missed:
        try:
            misfile = open('missed.txt', 'wt', encoding='utf-8')
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

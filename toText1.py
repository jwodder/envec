#!/usr/bin/python3
import argparse
import sys
from   envec import iloadJSON

parser = argparse.ArgumentParser()
parser.add_argument('infile', type=argparse.FileType('r'), default=sys.stdin)
args = parser.parse_args()

with args.infile:
    for card in iloadJSON(args.infile):
        print(card.toText1(0,1))

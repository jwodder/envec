#!/usr/bin/python3
# -*- coding: utf-8 -*-
import argparse
from   collections import defaultdict
import os
import os.path
import re
import sys
import envec

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('-L', '--latex', action='store_const', dest='format',
                        const='latex')
    parser.add_argument('-P', '--postscript', action='store_const',
                        dest='format', const='postscript')
    parser.add_argument('-d', '--dir', default='lists')
    parser.add_argument('-o', '--outfile', type=argparse.FileType('w', encoding='utf-8'))
    parser.add_argument('infile', type=argparse.FileType('r'),
                        default=sys.stdin)
    args = parser.parse_args()
    if args.outfile and args.format is not None:
        raise SystemExit('Single-file output is not implemented for'
                         ' LaTeX/PostScript')
    if not args.outfile:
        if not os.path.isdir(args.dir):
            os.mkdir(args.dir)
    if args.format is None:
        ext, showSet = '.txt', showTextSet
    elif args.format == 'latex':
        ext, showSet = '.tex', showLaTeXSet
    elif args.format == 'postscript':
        ext, showSet = '.ps', showPSSet

    setdb = envec.CardSetDB()
    sets = defaultdict(list)
    for card in envec.iloadJSON(args.infile):
        st = stats(card.part1)
        if card.isMultipart():
            st["part2"] = stats(card.part2)
        for p in card.printings:
            try:
                rarity = envec.Rarity.fromString(p.rarity)
            except KeyError:
                raise SystemExit('Unknown rarity %r for %s in %s'
                                 % (p.rarity, card.name, p.set))
            sets[str(p.set)].append(dict(st, num=p.effectiveNum(),
                                             rarity=rarity.longname.split()[0]))

    for cardset in setdb:
        cardset = str(cardset)
        if cardset not in sets:
            continue
        if args.outfile:
            outf = args.outfile
        else:
            outf = open(os.path.join(args.dir, re.sub(r'[ \'"]', '_', cardset)
                                                + ext), 'w', encoding='utf-8')
        special = []
        cards = []
        sets[cardset].sort(key=lambda c: (c["num"] or 0, c["name"]))
        for c in sets[cardset]:
            c["num"] = str(c["num"]) + '.' if c["num"] is not None else ''
            if c["special"]:
                special.append(c)
            else:
                cards.append(c)
                if "part2" in c:
                    cards.append(dict(c["part2"], num='//', rarity=''))
        if special and cards:
            cards = special + [None] + cards
        else:
            cards = special or cards
        showSet(cardset, outf, cards, args.outfile is not None)
        if not args.outfile:
            outf.close()


def stats(card):
    cost = card.cost or '--'
    if card.indicator:
        cost += ' [' + card.indicator + ']'
    extra = str(card.PT or card.loyalty or card.HandLife or '')
    return {
        "name":     card.name,
        "nameLen":  len(card.name),
        "type":     card.type,
        "typeLen":  len(card.type),
        "cost":     cost,
        "costLen":  len(cost),
        "extra":    extra,
        "extraLen": len(extra),
        "special":  card.isNontraditional(),
    }

def showLaTeXSet(cardset, outf, cards, singlefile):
    print(r'''
\documentclass{article}
\usepackage[top=1in,bottom=1in,left=1in,right=1in]{geometry}
\usepackage{graphicx}
\newcommand{\img}[1]{\\includegraphics[height=2ex]{../../rules/img/#1}}
\usepackage{longtable}
\usepackage{textcomp}
\begin{document}
\section*{%s}
\begin{longtable}[c]{rl|l|l|l|l}
No. & Name & Type & & Cost & \\ \hline \endhead
'''.strip() % (cardset,), file=outf)
    for c in cards:
        if c is None:
            print(r'\hline', file=outf)
            continue
        print(c["num"], '&', texify(c["name"]), '&', texify(c["type"]), '&',
              texify(c["extra"] or ''), '&', end=' ', file=outf)
        for gr in re.findall(r'\{(\d+|\D)\}|\{(.)/(.)\}|([^{}]+)', c["cost"]):
            if gr[3]:
                print(texify(gr[3]), end='', file=outf)
            else:
                print(r'\img{', gr[0] or gr[1]+gr[2], '.pdf}', sep='', end=' ',
                      file=outf)
        print('&', c["rarity"][0], r'\\', file=outf)
    print(r'\end{longtable}', file=outf)
    print(r'\end{document}', file=outf)

def texify(s):
    s = re.sub(r'(^|(?<=\s))"', '``', s)
    s = re.sub(r"(^|(?<=\s))'", '`', s)
    s = s.replace('--', '---')
    return s.translate({
        "[": r'\[',
        "]": r'\]',
        "&": r'\&',
        "{": r'\{',
        "}": r'\}',
        '"': "''",
        "’": "'",
        "Æ": r'\AE{}',
        "à": r'\`a',
        "á": r"\'a",
        "é": r"\'e",
        "í": r"\'{\i}",
        "ú": r"\'u",
        "â": r'\^a',
        "û": r'\^u',
        "ö": r'\"o',
        "®": r'\textsuperscript{\textregistered}',
        "½": r'\textonehalf',  # needs textcomp package
        "²": r'${}^2$',
    })

def showPSSet(cardset, outf, cards, singlefile):
    print(pshead, '/setData [', sep='', file=outf)
    costLen = 0
    for c in cards:
        if c is None:
            print(" [ () (---) () () {} /nop ]", file=outf)
            continue
        print(' [', '(' + c["num"] + ')', psify(c["name"]), psify(c["type"]),
              psify(c["extra"]), '{', end=' ', file=outf)
        clen = 0
        for gr in re.findall(r'\{(\d+)\}|\{(\D)\}|\{(.)/(.)\}|([^{}]+)',
                             c["cost"]):
            if gr[1]:
                print(gr[1], end=' ', file=outf)
                clen += 1
            elif gr[2]:
                print(gr[2] + gr[3], end=' ', file=outf)
            else:
                txt = gr[0] or gr[4]
                print(psify(txt), 'show', end=' ', file=outf)
                clen += len(txt)
        print('}', end=' ', file=outf)
        if clen > costLen:
            costLen = clen
        print('/' + (c["rarity"] or 'nop'), ']', file=outf)
    print('''\
] def
/setname (%s) def
/costLen %d circRad mul 2 mul def
showSet
showpage
''' % (cardset, costLen), file=outf)

def psify(s):
    s = s.replace('\\', r'\\')
    #s = s.replace('--', r'\320')
    # \320 is the StandardEncoding value for U+2014
    s = s.replace('--', '-')
    s = s.translate({
        "[": r'\[',
        "]": r'\]',
        "(": r'\(',
        ")": r'\)',
        "’": "'",
        "Æ": r'\306',
        "à": r'\340',
        "á": r'\341',
        "é": r'\351',
        "í": r'\355',
        "ú": r'\372',
        "â": r'\342',
        "û": r'\373',
        "ö": r'\366',
        "®": r'\256',
        "½": r'\275',
        "²": r'\262',
    })
    return '(' + s + ')'

def showTextSet(cardset, outf, cards, singlefile):
    nameLen = maxField('nameLen', cards)
    typeLen = maxField('typeLen', cards)
    costLen = maxField('costLen', cards)
    extraLen = maxField('extraLen', cards)
    print(cardset, file=outf)
    for c in cards:
        if c is None:
            print('---', file=outf)
        else:
            print('%4s %s  %s  %-*s  %-*s  %s'
                  % (c['num'],
                     c['name'] + ' ' * (nameLen - c['nameLen']),
                     c['type'] + ' ' * (typeLen - c['typeLen']),
                     extraLen, c['extra'],
                     costLen, c['cost'],
                     c['rarity']), file=outf)
    if singlefile:
        print('', file=outf)


def maxField(field, vals):
    return max(v[field] for v in vals if v is not None)

pshead = '''\
%!PS-Adobe-3.0

/mkLatin1 {  % old font, new name -- new font
 exch dup length dict begin
 { 1 index /FID ne { def } { pop pop } ifelse } forall
 /Encoding ISOLatin1Encoding def
 currentdict end definefont
} def

%/fontsize 10 def
%/lineheight 12 def
%/Monaco findfont /Monaco-Latin1 mkLatin1 fontsize scalefont setfont

/fontsize 8 def
/lineheight 10 def
/Times-Roman findfont /Times-Roman-Latin1 mkLatin1 fontsize scalefont setfont

/em (M) stringwidth pop def

/circRad fontsize 0.4 mul def
/circWidth circRad 2.1 mul def  % width of a "cell" containing a circle

/pageNo 0 def
/buf 3 string def

/linefeed {
 y 72 lineheight add le { showpage startPage } if
 /y y lineheight sub def
} def

/startPage {
 /pageNo pageNo 1 add def
 66 725 moveto setname show
 /pns pageNo buf cvs def
 546 pns stringwidth pop sub 725 moveto
 pns show
 66 722.5 moveto 480 0 rlineto stroke
 /y 722 def
} def

/nameStart 72 def
/showNum { dup stringwidth pop nameStart exch sub 3 sub y moveto show } def

/setcenter {
 currentpoint
 fontsize  2 div add /cy exch def
 circWidth 2 div add /cx exch def
} def

/disc {
 setcenter
 gsave
 setrgbcolor
 newpath cx cy circRad 0 360 arc fill
 grestore
 circWidth 0 rmoveto
} def

/W { 1 1 0.53 disc } def
/U { 0 0 1 disc } def
/B { 0 0 0 disc } def
/R { 1 0 0 disc } def
/G { 0 1 0 disc } def
/X { (X) show } def
/Y { (Y) show } def
/Z { (Z) show } def

/hybrid {
 gsave
 setcenter
 setrgbcolor newpath cx cy circRad 225 45 arc fill  % bottom half
 setrgbcolor newpath cx cy circRad 45 225 arc fill  % top half
 grestore
 circWidth 0 rmoveto
} def

/WU { 1 1 0.53  0 0 1  hybrid } def
/WB { 1 1 0.53  0 0 0  hybrid } def
/UB { 0 0 1     0 0 0  hybrid } def
/UR { 0 0 1     1 0 0  hybrid } def
/BR { 0 0 0     1 0 0  hybrid } def
/BG { 0 0 0     0 1 0  hybrid } def
/RG { 1 0 0     0 1 0  hybrid } def
/RW { 1 0 0     1 1 0.53 hybrid } def
/GW { 0 1 0     1 1 0.53 hybrid } def
/GU { 0 1 0     0 0 1  hybrid } def
/2W { 0.8 0.8 0.8  1 1 0.53  hybrid } def
/2U { 0.8 0.8 0.8  0 0 1     hybrid } def
/2B { 0.8 0.8 0.8  0 0 0     hybrid } def
/2R { 0.8 0.8 0.8  1 0 0     hybrid } def
/2G { 0.8 0.8 0.8  0 1 0     hybrid } def

/phi {
 gsave
 circWidth neg 0 rmoveto
 setcenter
 setrgbcolor
 newpath cx cy circRad 0 360 arc clip
 newpath
 currentlinewidth 2 div setlinewidth
 cx cy circRad 2 div 0 360 arc
 cx cy circRad add moveto
 0 circRad -2 mul rlineto
 stroke
 grestore
} def

/WP { W 0 0 0 phi } def
/UP { U 1 1 1 phi } def
/BP { B 1 1 1 phi } def
/RP { R 1 1 1 phi } def
/GP { G 0 0 0 phi } def

/Mythic   { rareStart y moveto (Mythic)   show } def
/Rare     { rareStart y moveto (Rare)     show } def
/Uncommon { rareStart y moveto (Uncommon) show } def
/Common   { rareStart y moveto (Common)   show } def
/Land     { rareStart y moveto (Land)     show } def
/Special  { rareStart y moveto (Special)  show } def
/Promo    { rareStart y moveto (Promo)    show } def
/Bonus    { rareStart y moveto (Bonus)    show } def
/nop { } def

/showSet {
 /nameLen 0 def
 /typeLen 0 def
 /extraLen 0 def
 setData {
  aload pop pop pop
  stringwidth pop dup extraLen gt { /extraLen exch def } { pop } ifelse
  stringwidth pop dup typeLen  gt { /typeLen  exch def } { pop } ifelse
  stringwidth pop dup nameLen  gt { /nameLen  exch def } { pop } ifelse
  pop
 } forall
 /typeStart  nameStart  nameLen  2 em mul add add def
 /extraStart typeStart  typeLen  2 em mul add add def
 /costStart  extraStart extraLen 2 em mul add add def
 /rareStart  costStart  costLen  2 em mul add add def
 startPage
 setData {
  % [ number name type extra { cost } rarity ]
  linefeed
  dup 0 get showNum
  dup 1 get nameStart y moveto show
  dup 2 get typeStart y moveto show
  dup 3 get extraStart y moveto show
  dup 4 get costStart y moveto exec
  5 get cvx exec
 } forall
} def

% [ number name type extra { cost } rarity ]
% The Python code defines: setData, setname, costLen
'''

if __name__ == '__main__':
    main()

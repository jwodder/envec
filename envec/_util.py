# -*- coding: utf-8 -*-
import itertools
import re
import sys
import textwrap
from   xml.dom import Node

def trim(txt): return None if txt is None else txt.strip()

def simplify(txt): return None if txt is None else re.sub(r'\s+',' ',trim(txt))

def uniq(xs): return [k for k,_ in itertools.groupby(xs)]
 # The list must be pre-sorted.

def wrapLines(txt, length=80, postdent=0):
    lines = []
    for line in txt.rstrip().splitlines():
        line = line.rstrip()
        if line == '': lines.append('')
        else: lines.extend(textwrap.wrap(line, length,
                                         subsequent_indent=' ' * postdent,
                                         break_long_words=False,
                                         break_on_hyphens=False))
    return lines

def magicContent(node):
    # Like textContent, but better ... for its intended purpose
    # cf. <http://www.w3.org/TR/2004/REC-DOM-Level-3-Core-20040407/core.html#Node3-textContent>
    if node is None: return ''
    elif node.nodeType == Node.TEXT_NODE:
        return node.nodeValue.replace('&nbsp;', ' ')
    elif node.nodeType == Node.ELEMENT_NODE:
        if node.nodeName.lower() == 'br': return "\n"
        elif node.nodeName.lower() == 'i':
            return '<i>' + ''.join(map(magicContent, node.childNodes)) + '</i>'
        elif node.nodeName.lower() == 'img':
            src = node.getAttribute('src')
            m = re.search(r'\bname=(\w+)\b', src)
            if m:
                sym = m.group(1).upper()
                m = re.search(r'^([2WUBRG])([WUBRGP])$', sym)
                if m: return '{%s/%s}' % m.groups()
                elif sym == 'TAP': return '{T}'
                elif sym == 'UNTAP': return '{Q}'
                elif sym == 'SNOW': return '{S}'
                elif sym == 'INFINITY': return '{∞}'  # Mox Lotus
                elif sym == '500': return '{HALFW}'
                # It appears that the only fractional mana symbols are
                # half-white (Little Girl; name=500), half-red (Mons's Goblin
                # Waiters; name=HalfR), and half-colorless (Flaccify and Cheap
                # Ass; erroneously omitted from the rules texts).
                else: return '{' + sym + '}'
            elif re.search(r'\bchaos\.(gif|png)$', src): return '{C}'
            else: return '[' + src + ']'
        else: return ''.join(map(magicContent, node.childNodes))
### else: ???

def parseTypes(arg):
    arg = simplify(arg)
    m = re.search(r' ?— ?| -+ ', arg)  # The first "hyphen" is U+2014.
    (types, sub) = (arg[:m.start()], arg[m.end():]) if m else (arg, None)
    m = re.search(r'^(Summon|Enchant)(?: (.+))?$', types, re.I)
    if m: return ([], [m.group(1)], [m.group(2) or sub])
    sublist = [sub] if types == 'Plane' else (sub or '').split()
     # Assume that Plane cards never have supertypes or other card types.
    typelist = types.split()
    superlist = []
    while typelist and typelist[0].title() in ('Basic', 'Legendary', 'Ongoing',
                                               'Snow', 'World'):
        superlist.append(typelist.pop(0))
    return (superlist, typelist, sublist)

def txt2xml(txt):
    txt = txt.replace('&', '&amp;')
    txt = txt.replace('<', '&lt;')
    txt = txt.replace('>', '&gt;')
    return txt

def txt2attr(txt): return txt2xml(txt).replace('"', '&quot;')

def sym2xml(txt):
    txt = txt2xml(txt)
    txt = re.sub(r'&lt;(/?i)&gt;', lambda m: '<%s>' % m.group(1).lower(), txt,
                 flags=re.I)
    txt = re.sub(r'\{(\d+|∞)\}', r'<m>\1</m>', txt)
    txt = re.sub(r'\{([WUBRGPXYZSTQ])\}', r'<\1/>', txt)
    txt = re.sub(r'\{([WUBRG])/([WUBRGP])\}', r'<\1\2/>', txt)
    txt = re.sub(r'\{2/([WUBRG])\}', r'<\g<1>2/>', txt)
    txt = re.sub(r'\{PW\}', r'<PW/>', txt)
    txt = re.sub(r'\{C\}', r'<chaos/>', txt)
    return txt

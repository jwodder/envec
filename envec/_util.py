# -*- coding: utf-8 -*-
from   __future__ import unicode_literals
import itertools
import re
import textwrap
import bs4
from   six.moves.urllib.parse import urlparse, parse_qs

def trim(txt):
    return None if txt is None else txt.strip()

def simplify(txt):
    return None if txt is None else re.sub(r'\s+', ' ', trim(txt))

def uniq(xs):
    # The list must be pre-sorted.
    return [k for k,_ in itertools.groupby(xs)]

def wrapLines(txt, length=80, postdent=0):
    lines = []
    for line in txt.rstrip().splitlines():
        line = line.rstrip()
        if line == '':
            lines.append('')
        else:
            lines.extend(textwrap.wrap(line, length,
                                       subsequent_indent=' ' * postdent,
                                       break_long_words=False,
                                       break_on_hyphens=False))
    return lines

def magicContent(node):
    if type(node) is bs4.NavigableString or type(node) is bs4.CData:
        # Using `type` instead of `isinstance` weeds out comments, doctypes,
        # etc.
        return unicode(node).replace(u'\xA0', u' ')
    elif isinstance(node, bs4.Tag):
        if node.name == 'br':
            return '\n'
        elif node.name == 'i':
            return '<i>' + ''.join(map(magicContent, node.children)) + '</i>'
        elif node.name == 'img':
            src = node['src']
            params = parse_qs(urlparse(src).query)
            if 'name' in params:
                sym = params['name'][0].upper()
                m = re.search(r'^([2WUBRG])([WUBRGP])$', sym)
                if m:
                    return '{%s/%s}' % m.groups()
                elif sym == 'TAP':
                    return '{T}'
                elif sym == 'UNTAP':
                    return '{Q}'
                elif sym == 'SNOW':
                    return '{S}'
                elif sym == 'INFINITY':
                    return '{∞}'  # Mox Lotus
                elif sym == '500':
                    return '{HALFW}'
                # It appears that the only fractional mana symbols are
                # half-white (Little Girl; name=500), half-red (Mons's Goblin
                # Waiters; name=HalfR), and half-colorless (Flaccify and Cheap
                # Ass; erroneously omitted from the rules texts).
                else:
                    return '{' + sym + '}'
            elif re.search(r'\bchaos\.(gif|png)$', src):
                return '{C}'
            else:
                return '[' + src + ']'
        else:
            return ''.join(map(magicContent, node.children))
    else:
        return ''

def parseTypes(arg):
    split = re.split(r' ?\u2014 ?| -+ ', simplify(arg), maxsplit=1)
    superlist = []
    types = split[0]
    if len(split) == 1:
        sublist = []
    elif types == 'Plane':
        # Assume that Plane cards never have supertypes or other card types.
        sublist = [split[1]]
    else:
        sublist = split[1].split()
    m = re.search(r'^(Summon|Enchant)(?: (.+))?$', types, re.I)
    if m:
        typelist = [m.group(1)]
        if m.group(2) is not None:
            sublist.insert(0, m.group(2))
    else:
        typelist = types.split()
        while typelist and typelist[0].title() in ('Basic', 'Legendary',
                                                   'Ongoing', 'Snow', 'World'):
            superlist.append(typelist.pop(0))
    return (superlist, typelist, sublist)

def txt2xml(txt):
    txt = unicode(txt)
    txt = txt.replace('&', '&amp;')
    txt = txt.replace('<', '&lt;')
    txt = txt.replace('>', '&gt;')
    return txt

def txt2attr(txt):
    return txt2xml(txt).replace('"', '&quot;')

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

def cheap_repr(obj):
    return obj.__class__.__name__ + '(' + ', '.join('%s=%r' % kv for kv in vars(obj).iteritems()) + ')'

def maybeInt(s):
    try:
        return int(s)
    except ValueError:
        return s

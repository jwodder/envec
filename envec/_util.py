# -*- coding: utf-8 -*-
from   collections  import Iterable
import itertools
import re
import textwrap
from   urllib.parse import urlparse, parse_qs
import bs4

def simplify(txt):
    return None if txt is None else re.sub(r'\s+', ' ', txt.strip())

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
        return str(node).replace('\xA0', ' ')
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

def cheap_repr(obj):
    return obj.__class__.__name__ + '(' + ', '.join('%s=%r' % kv for kv in vars(obj).items()) + ')'

def maybeInt(s):
    try:
        return int(s)
    except ValueError:
        return s

def split_mana(s):
    mana = []
    while True:
        m = re.search(r'^\s*\{([^{}]+)\}\s*', s)
        if m:
            mana.append(m.group(1))
            s = s[m.end():]
        else:
            return (mana, s)

def for_json(obj, trim=False):
    # Note that `trim` is not inherited.  This is deliberate, as `trim` should
    # only be `True` when called by an object's `for_json` method.
    if isinstance(obj, list):
        return list(map(for_json, obj))
    elif isinstance(obj, dict):
        data = dict()
        for k,v in obj.items():
            v = for_json(v)
            # Note that this automatically gets rid of empty Multivals.
            if not (trim and (v is None or \
                    (isinstance(v, Iterable) and not v))):
                data[k] = v
        return data
    elif hasattr(obj, 'for_json'):
        return obj.for_json()
    else:
        return obj

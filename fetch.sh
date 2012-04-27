#!/bin/bash
[ -e ids.txt ] || perl uniqIDs.pl data/sets.tsv > ids.txt || exit
date +'Start: %s'
perl details.pl -l details.log -C ids.txt || exit
date +'End: %s'
perl toText1.pl out/details.json > out/cards2.txt

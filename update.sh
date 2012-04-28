#!/bin/sh
setfile=data/sets.tsv
details=out/details

currSet=`awk -F'\t+' '/^[^#]/ { print $3 "\t" $1 }' $setfile | sort -r | head -n1 | cut -f2`
dir=$details/`date +%Y%m%d`-$currSet
mkdir -p "$dir"

[ -e ids.txt ] || perl uniqIDs.pl $setfile > ids.txt || exit

date +'Start: %s'
perl details.pl -C ids.txt -l details.log -S $setfile \
		-j "$dir/details.json" -x "$dir/details.xml" || exit
date +'End: %s'

#rm ids.txt

perl toText1.pl "$dir/details.json" > out/cards2.txt

### Regenerate lists.txt too?

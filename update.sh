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

[ -e out/details0.json ] && diff -u out/details0.json "$dir/details.json" > out/details.json.diff
[ -e out/details0.xml ] && diff -u out/details0.xml "$dir/details.xml" > out/details.xml.diff

#rm -f out/details0.json out/details0.xml
#ln -s "$dir/details.json" ...
#ln -s "$dir/details.xml" ...

### Regenerate lists.txt too?

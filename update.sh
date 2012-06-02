#!/bin/sh
setfile=data/sets.tsv
currSet=`awk -F'\t+' '/^[^#]/ { print $3 "\t" tolower($1) }' $setfile | sort -r | head -n1 | cut -f2`
dir=`date +%Y%m%d`-$currSet
echo Creating "$dir"
mkdir -p "out/$dir"

[ -e ids.txt ] || perl details.pl -S $setfile -I ids.txt || exit
date +'Start: %s'
perl details.pl -S $setfile -C ids.txt -l details.log \
		-j "out/$dir/details.json" -x "out/$dir/details.xml" || exit
date +'End: %s'
perl toText1.pl "out/$dir/details.json" > out/cards2.txt
perl listify.pl -o out/cardlists2.txt "out/$dir/details.json"

cd out
diff -Nu details0.json "$dir/details.json" > details.json.diff
diff -Nu details0.xml  "$dir/details.xml"  > details.xml.diff
rm -f details0.json details0.xml
ln -s "$dir/details.json" details0.json
ln -s "$dir/details.xml"  details0.xml

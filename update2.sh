#!/bin/sh
# invoke with: nice nohup ./update2.sh &
setfile=data/sets.tsv
currSet=`awk -F'\t+' '/^[^#]/ { print $3 "\t" tolower($1) }' $setfile | sort -r | head -n1 | cut -f2`
dir=`date +%Y%m%d`-$currSet
echo Creating "out/$dir"
mkdir -p "out/$dir"

[ -e ids.txt ] || perl details.pl -S $setfile -I ids.txt || exit
date +'Start: %s'
perl details.pl -S $setfile -C ids.txt \
		-j "out/$dir/details.json" -x "out/$dir/details.xml" || exit
date +'End: %s'
perl toText1.pl "out/$dir/details.json" > out/cards2.txt
perl listify.pl -o out/cardlists2.txt "out/$dir/details.json"

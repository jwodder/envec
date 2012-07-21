#!/bin/sh
# invoke with: nice ./update2.sh &
setfile=data/sets.tsv
currSet=`awk -F'\t+' '/^[^#]/ { print $3 "\t" tolower($1) }' $setfile | sort -r | head -n1 | cut -f2`
dir=`date +%Y%m%d`-$currSet
echo Creating "out/$dir"
mkdir -p "out/$dir"

if [ -e ids.txt ] then Ci=-C else Ci=-i fi
perl details.pl -S $setfile $Ci ids.txt -l details.log \
		-j "out/$dir/details.json" -x "out/$dir/details.xml" || exit
perl toText1.pl "out/$dir/details.json" > out/cards2.txt
perl listify.pl -o out/cardlists2.txt "out/$dir/details.json"
echo '# vim:set nowrap:' >> out/cardlists2.txt

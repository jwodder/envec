#!/bin/sh
# invoke with: nice ./update.sh &
setfile=data/sets.tsv
currSet=`awk -F'\t+' '/^[^#]/ { print $3 "\t" tolower($1) }' $setfile | sort -r | head -n1 | cut -f2`
base=`date -u +%Y%m%d`-$currSet

Ci=i
[ -e ids.txt ] && Ci=C
mkdir -p out
perl details.pl -S "$setfile" -$Ci ids.txt -l details.log \
		-j "out/$base.json" -x "out/$base.xml" || exit
perl toText1.pl "out/$base.json" > out/cards2.txt
perl listify.pl -o out/cardlists2.txt "out/$base.json"
echo '# vim:set nowrap:' >> out/cardlists2.txt
chmod -w "out/$base.json" "out/$base.xml" out/cards2.txt out/cardlists2.txt

#cd out
#diff -Nu details.json "$base.json" > details.json.diff
#diff -Nu details.xml  "$base.xml"  > details.xml.diff
#rm -f details.json details.xml
#ln -s "$base.json" details.json
#ln -s "$base.xml"  details.xml

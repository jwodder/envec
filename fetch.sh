#!/bin/sh
# invoke with: nice ./fetch.sh &
dir=fetched
setfile=data/sets.tsv
currSet=`awk -F'\t+' '/^[^#]/ { print $3 "\t" tolower($1) }' $setfile | sort -r | head -n1 | cut -f2`
base=`date -u +%Y%m%d`-$currSet

Ci=i
[ -e "$dir/ids.txt" ] && Ci=C

mkdir -p $dir
perl tutor.pl -S "$setfile" -$Ci "$dir/ids.txt" -l "$dir/tutor.log" \
	      -j "$dir/$base.json" -x "$dir/$base.xml" || exit

perl toText1.pl "$dir/$base.json" > "$dir/cards2.txt"

perl listify.pl -o "$dir/cardlists2.txt" "$dir/$base.json"
echo '# vim:set nowrap:' >> "$dir/cardlists2.txt"

chmod -w "$dir/$base.json" "$dir/$base.xml"
chmod -w "$dir/cards2.txt" "$dir/cardlists2.txt"

#!/bin/sh
# invoke with: nice ./fetch.sh &
outdir=out
setfile=data/sets.tsv
currSet=`awk -F'\t+' '/^[^#]/ { print $3 "\t" tolower($1) }' $setfile | sort -r | head -n1 | cut -f2`
base=`date -u +%Y%m%d`-$currSet

Ci=i
[ -e ids.txt ] && Ci=C

mkdir -p $outdir
perl tutor.pl -S "$setfile" -$Ci ids.txt -l tutor.log \
	      -j "$outdir/$base.json" -x "$outdir/$base.xml" || exit

perl toText1.pl "$outdir/$base.json" > "$outdir/cards2.txt"

perl listify.pl -o $outdir/cardlists2.txt "$outdir/$base.json"
echo '# vim:set nowrap:' >> "$outdir/cardlists2.txt"

chmod -w "$outdir/$base.json" "$outdir/$base.xml"
chmod -w "$outdir/cards2.txt" "$outdir/cardlists2.txt"

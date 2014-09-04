#!/bin/bash
# Recommended invocation: nice ./fetch.sh &
dir=fetched
args=`getopt o:b: $*` || {
 echo "Usage: $0 [-o dir] [-b base] [setfile]";
 exit 2;
}
set -- $args
for i
do case "$1" in
 -o) dir="$2"; shift; shift;;
 -b) base="$2"; shift; shift;;
 --) shift; break;;
esac done

if [ -n "$1" ]
then setfile="$1"
else setfile=data/sets.tsv
fi

if [ -z "$base" ]
then currSet=`awk -F'\t+' '/^[^#]/ { print $3 "\t" tolower($1) }' $setfile | sort -r | head -n1 | cut -f2`
     base=`date -u +%Y%m%d`-$currSet
fi

Ci=i
[ -e "$dir/ids.txt" ] && Ci=C

mkdir -p "$dir"
perl tutor.pl -S "$setfile" \
	      -$Ci "$dir/ids.txt" \
	      -l "$dir/tutor.log" \
	      -j "$dir/$base.json" \
	      -x "$dir/$base.xml" || exit

perl toText1.pl "$dir/$base.json" > "$dir/cards.txt"

perl listify.pl -o "$dir/cardlists.txt" "$dir/$base.json"
echo '# vim:set nowrap:' >> "$dir/cardlists.txt"

chmod -w "$dir/$base.json" "$dir/$base.xml"
chmod -w "$dir/cards.txt" "$dir/cardlists.txt"

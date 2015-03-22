#!/bin/bash
# Recommended invocation: nice ./fetch.sh &
#
# Options:
#  -b base - Use `base` as the basename of the JSON & XML output files instead
#            of the current date and most recent set abbreviation
#  -i ids - Write card IDs to (or, if it already exists, read card IDs from)
#           `ids` instead of `ids.txt` in the output directory
#  -o dir - Place output files in `dir` instead of `fetched/`
#
# Optional command-line argument: the setfile

dir=fetched
args=`getopt b:i:o: $*` || {
 echo "Usage: $0 [-b base] [-i ids] [-o dir] [setfile]";
 exit 2;
}
set -- $args
for i
do case "$1" in
 -o) dir="$2";  shift; shift;;
 -b) base="$2"; shift; shift;;
 -i) ids="$2";  shift; shift;;
 --) shift; break;;
esac done

setfile="${1:-data/sets.tsv}"

if [ -z "$base" ]
then currSet=`awk -F'\t+' '/^[^#]/ { print $3 "\t" tolower($1) }' $setfile | sort -r | head -n1 | cut -f2`
     base=`date -u +%Y%m%d`-$currSet
fi

Ci=i
[ -e "${ids:=$dir/ids.txt}" ] && Ci=C

mkdir -p "$dir"
perl tutor.pl -S "$setfile" \
	      -$Ci "$ids" \
	      -l "$dir/tutor.log" \
	      -j "$dir/$base.json" \
	      -x "$dir/$base.xml" || exit

perl toText1.pl "$dir/$base.json" > "$dir/cards.txt"

perl listify.pl -o "$dir/cardlists.txt" "$dir/$base.json"
echo '# vim:set nowrap:' >> "$dir/cardlists.txt"

chmod -w "$dir/$base.json" "$dir/$base.xml"
chmod -w "$dir/cards.txt" "$dir/cardlists.txt"

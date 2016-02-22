#!/bin/bash
# Recommended invocation: nice ./fetch.sh &
#
# Options:
#  -b base - Use `base` as the basename of the JSON output files instead
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

set -e

setfile="${1:-data/sets.json}"

if [ -z "$base" ]
then currSet=`jq -r 'max_by(.release_date) | .abbreviations.Gatherer' $setfile`
     base=`date -u +%Y%m%d`-$currSet
fi

Ci=i
[ -s "${ids:=$dir/ids.txt}" ] && Ci=C

mkdir -p "$dir"
python3 tutor.py -S "$setfile" \
                 -$Ci "$ids" \
                 -j "$dir/$base.json" \
                 -l "$dir/tutor.log"

python3 toText1.py "$dir/$base.json" > "$dir/cards.txt"

python3 listify.py -o "$dir/cardlists.txt" "$dir/$base.json"
echo '# vim:set nowrap:' >> "$dir/cardlists.txt"

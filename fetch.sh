#!/bin/bash
# Recommended invocation: nice ./fetch.sh &
#
# Options:
#  -b base - Use `base` as the basename of the JSON output files instead
#            of the current date and most recent set abbreviation
#  -o dir - Place output files in `dir` instead of `fetched/`
#
# Optional command-line argument: the setfile

dir=fetched
args=`getopt b:i:o: $*` || {
 echo "Usage: $0 [-b base] [-o dir] [setfile]";
 exit 2;
}
set -- $args
for i
do case "$1" in
 -o) dir="$2";  shift; shift;;
 -b) base="$2"; shift; shift;;
 --) shift; break;;
esac done

set -e

setfile="${1:-data/sets.json}"

if [ -z "$base" ]
then currSet=`jq -r 'max_by(.release_date) | .abbreviations.Gatherer' $setfile`
     base=`date -u +%Y%m%d`-$currSet
fi

mkdir -p "$dir"
python3 tutor.py -S "$setfile" \
                 -o "$dir/$base.json" \
                 -l "$dir/tutor.log"

python3 toText1.py "$dir/$base.json" > "$dir/cards.txt"

python3 listify.py -o "$dir/cardlists.txt" "$dir/$base.json"
echo '# vim:set nowrap:' >> "$dir/cardlists.txt"

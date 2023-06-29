#!/bin/sh

# python=pypy3
python=python3.9
# sqlite=/usr/local/Cellar/sqlite/3.36.0/bin/sqlite3
sqlite=/usr/bin/sqlite3
data_path=./data
# wikidata_all=$data_path/test-100.json.gz
wikidata_all=$data_path/latest-all.json.gz
# lines_per_part=25
lines_per_part=10000000
wikidata_part_substr=.part-
term_out_suffix=.term_tsv.gz
# db_file=$data_path/wdsqlite.db
db_file=./data/wdsqlite.db

## SPLIT
time pigz -dc $wikidata_all | gsplit - -l $lines_per_part --filter='pigz > $FILE.json.gz' $wikidata_all$wikidata_part_substr

## EXTRACT TSV PARALLEL
pids=""
RESULT=0
for file in $(find $data_path -type f -name "*$wikidata_part_substr*"); do
    time $python ./util/extractwikitrans.py $file $file$term_out_suffix & 
    pids="$pids $!"
done
# wait $pids
for pid in $pids; do
    wait $pid || let "RESULT=1"
done
if [ "$RESULT" == "1" ]; then { exit 1; }; fi

## CREATE SQLITE DB
touch $db_file
$sqlite $db_file < ./util/create-tables.sql
time gzcat $(find $data_path -type f -name "*$term_out_suffix") | $sqlite -tabs $db_file ".import /dev/stdin term"
time $sqlite $db_file < ./util/create-indexsummary.sql

## CLEANUP 
rm $data_path/*$wikidata_part_substr*
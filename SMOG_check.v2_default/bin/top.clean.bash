#!/bin/bash
FILE=$1
OUT=$2
grep -v ';' $FILE | grep -v "^ *$" | awk '{print $1,$2,$3,$4,$5,$6,$7,$8,$9,$10}' > $OUT

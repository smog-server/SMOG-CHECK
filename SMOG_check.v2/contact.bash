#!/bin/bash
filename_c=$1
mv $filename_c ok.$filename_c
wc -l ok.$filename_c | awk '{print $1}' > kk.$filename_c
echo 0 > kk1.$filename_c
paste kk.$filename_c kk1.$filename_c > $filename_c
cat ok.$filename_c >>  $filename_c
rm ok.$filename_c kk*.$filename_c

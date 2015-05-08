#!/bin/bash


export EXEC_SMOG=/home/pcw2/SMOGV2_031513/smogv2
export TOLERANCE=0.001
export PRECISION=10000



echo STARTING the cutoff analysis

rm -r FAILED.cutoff
mkdir FAILED.cutoff
for i in DBZ B12 tRNA.gly ci2 SAM DNA  1AKE 1AKE_ATP 1AKE_ADP 1AKE_AMP GNP EFG_FUA_GDP rib AAPP 3F1FE 3IZH 
do
echo inputfiles/input.$i | ./check.cutoff.v1.2.pl
done


echo STARTING the shadow analysis

rm -r FAILED.shadow
mkdir FAILED.shadow

for i in  DBZ B12 ci2 SAM DNA  1AKE 1AKE_ATP 1AKE_ADP 1AKE_AMP GNP EFG_FUA_GDP rib AAPP 3F1FE 3IZH
do
echo inputfiles/input.$i | ./check.shadow.v1.2.pl
done

echo STARTING the cutoff analysis with gaussians

rm -r FAILED.cutoff.gauss
mkdir FAILED.cutoff.gauss
for i in DBZ B12 tRNA.gly ci2 SAM DNA  1AKE 1AKE_ATP 1AKE_ADP 1AKE_AMP GNP EFG_FUA_GDP rib AAPP 3F1FE  3IZH
do
echo inputfiles/input.$i | ./check.cutoff.gauss.v1.2.pl
done



echo STARTING the shadow analysis with gaussians

rm -r FAILED.shadow.gauss
mkdir FAILED.shadow.gauss

for i in  DBZ B12 ci2 SAM DNA  1AKE 1AKE_ATP 1AKE_ADP 1AKE_AMP GNP EFG_FUA_GDP rib AAPP 3F1FE 3IZH
do
echo inputfiles/input.$i | ./check.shadow.gauss.v1.2.pl
done



echo STARTING the shadow analysis with CA

rm -r FAILED.shadow.CA
mkdir FAILED.shadow.CA

for i in  DBZ.CA ci2.CA 1AKEapo.CA rop.CA 3IZH
do
echo inputfiles/input.$i | ./check.shadow.CA.v1.2.pl
done


echo STARTING the shadow analysis with CA and gaussians

rm -r FAILED.shadow.CA.gauss
mkdir FAILED.shadow.CA.gauss

for i in  DBA.CA ci2.CA 1AKEapo.CA rop.CA 3IZH
do
echo inputfiles/input.$i | ./check.shadow.CA.gauss.v1.2.pl
done




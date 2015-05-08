#!/bin/bash


SMOG_ROOT=/home/pcw2/SMOG_check.v2_default/mohit_rice-smog2-b09b3038cd8a
source $SMOG_ROOT/config.bash $SMOG_ROOT
export EXEC_SMOG=$SMOG_ROOT/smogv2
export BIFSIF=$SMOG_ROOT/SBM
export BIFSIF_CA=$SMOG_ROOT/SBM_calpha

checkCA=1
checkAA=1

export TOLERANCE=0.001
export PRECISION=10000



if [ $checkCA == 1 ]
then
	echo STARTING the shadow analysis with CA

	rm -r FAILED.shadow.CA
	mkdir FAILED.shadow.CA

	for i in ci2.CA 1AKEapo.CA rop.CA 3IZH
	do
	echo inputfiles/input.$i | ./check.shadow.CA.v2.pl
	done

fi



if [ $checkAA == 1 ]
then
	echo STARTING the shadow analysis

	rm -r FAILED.shadow
	mkdir FAILED.shadow

	for i in ci2 SAM_v2 3IZH  rib DNA 
	do
	echo inputfiles/input.$i | ./check.shadow.v2.pl
	done
fi

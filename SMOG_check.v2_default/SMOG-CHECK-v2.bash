#!/bin/bash


SMOG_ROOT=/home/whitford/git.repos/smog2-pcw/
source $SMOG_ROOT/config.bash $SMOG_ROOT
export EXEC_SMOG=$SMOG_ROOT/smogv2
export BIFSIF=$SMOG_ROOT/SBM
export BIFSIF_CA=$SMOG_ROOT/SBM_calpha

checkCA=1
checkAA=0

# Insert descriptions of each of these quantities

export TOLERANCE=0.001
export PRECISION=10000



if [ $checkCA == 1 ]
then
	echo STARTING analysis of the CA model with a shadow map

	rm -r FAILED.shadow.CA
	mkdir FAILED.shadow.CA

	for i in ci2.CA 1AKEapo.CA rop.CA 3IZH
	do
	echo inputfiles/input.$i | ./check.shadow.default.CA.v2.pl
	done

fi



if [ $checkAA == 1 ]
then
	echo STARTING analysis of the all-atom model with a shadow map

	rm -r FAILED.shadow
	mkdir FAILED.shadow

	for i in ci2 SAM_v2 3IZH  rib DNA 
	do
	echo inputfiles/input.$i | ./check.shadow.defaul.v2.pl
	done
fi

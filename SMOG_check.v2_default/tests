#!/bin/bash

# When everything works well, all you need to do is define SMOG_ROOT (the location of the smog executable)
SMOG_ROOT=/home/whitford/git.repos/smog2-pcw/
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
	echo STARTING analysis of the CA model with a shadow map
	rm -r FAILED.shadow.CA
	mkdir FAILED.shadow.CA
	echo PDB.files/calpha.pdbs | bin/check.shadow.CA.default.v2.pl
fi


if [ $checkAA == 1 ]
then
	echo STARTING analysis of the all-atom model with a shadow map
	rm -r FAILED.shadow
	mkdir FAILED.shadow
	echo PDB.files/allatom.pdb | bin/check.shadow.default.v2.pl
fi

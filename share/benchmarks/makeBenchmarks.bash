for pdb in 1AKEapo_v2 1ypa.2chains 2GIS_noSAM_v2
do
for graining in AA CA
do

if [ -e $pdb.$graining.pdb ]
then

$perl4smog $SMOG_PATH/src/smogv2 -i $pdb.$graining.pdb -$graining -dname temporary
mv temporary.top $pdb.$graining.top
rm temporary*
fi

done
done

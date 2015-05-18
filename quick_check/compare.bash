PATH_TO_SMOG2=$1
dir=$(pwd)

for pdb in CI2
do

cd $PATH_TO_SMOG2
./smogv2 -i $dir/templates/$pdb.pdb -tAA SBM_AA -contactRes SBM_AA -o $dir/testing/$pdb.top -g $dir/testing/$pdb.gro -s $dir/testing/$pdb.shadow -n $dir/testing/$pdb.ndx &> /dev/null
cd $dir
perl compare.pl templates/$pdb.top testing/$pdb.top > testing/$pdb.test

a=$(grep ERROR testing/$pdb.test | wc -l | awk '{print $1}')
if [ $a -gt 0 ]
then
echo There are errors. Check testing/$pdb.test for details.
else
echo Congratulations there are no errors for $pdb.
fi

done

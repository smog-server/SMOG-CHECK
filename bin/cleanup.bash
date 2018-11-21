#!/bin/bash

echo Will clean up files that may have been generated by an earlier execution of the test script
for i in table.2.xvg table.xvg .map .pdb .gro .contacts .settings output. .output .top .ndx shadow.log FAILED  .bifsif .contacts.SCM meta.Gro testing .mdp .tpr
do
	for i in `find . -maxdepth 1 -name "*$i*"`
	do
		if [ -f $i ]
		then
			rm $i
			echo rm $i
		elif [ -d $i ]
		then
			rm -r $i
			echo rm -r $i
		fi

	done
done
echo done cleaning up 

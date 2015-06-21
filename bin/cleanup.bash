#!/bin/bash

echo Will clean up files that may have been generated by an earlier execution of the test script
for i in .gro .contacts .settings .output .top .ndx shadow.log FAILED  .bifsif .contacts.SCM 
do
	for i in `find ./ -maxdepth 1 -name "*$i*"`
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
echo done

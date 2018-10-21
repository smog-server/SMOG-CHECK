
types="X X1 X2"

for i in $types
do

	echo atom $i

	for j in $types
	do
		echo bond $i $j
		for k in $types
		do
			echo angle $i $j $k
	
			for l in $types
			do
				echo dihedral $i $j $k $l
	
			done
		done
	
	done
done

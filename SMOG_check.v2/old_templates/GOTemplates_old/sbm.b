<?xml version='1.0'?>
<b>
<!-- BONDS -->
<bonds>
	<bond func="test_bonds(?,20000)">
	<bType>*</bType>
	<bType>*</bType>
	</bond>
        
</bonds>

<!-- ANGLES -->
<angles>
	<angle func="test_angles(?,40)">
	<bType>*</bType>
	<bType>*</bType>
	<bType>*</bType>
	</angle>
</angles>

<!-- DIHEDRALS -->
<dihedrals>
	<dihedral func="test_dihedrals(?,?,1)+test_dihedrals(?*3,?*0.5,3)" energyGroup="bb">
	<bType>*</bType>
	<bType>*</bType>
	<bType>*</bType>
	<bType>*</bType>
	</dihedral>
	<dihedral func="test_dihedrals(?,?,1)+test_dihedrals(?*3,?*0.5,3)" energyGroup="sc">
	<bType>*</bType>
	<bType>*</bType>
	<bType>*</bType>
	<bType>*</bType>
	</dihedral>
	<dihedral func="test_planarRigid(?,40)" energyGroup="pr">
	<bType>*</bType>
	<bType>*</bType>
	<bType>*</bType>
	<bType>*</bType>
	</dihedral>
	<dihedral func="test_rigid(?,10)" energyGroup="r">
	<bType>*</bType>
	<bType>*</bType>
	<bType>*</bType>
	<bType>*</bType>
	</dihedral>
</dihedrals>

<!-- IMPROPERS -->
<impropers>
	<improper func="test_improper(?,10)">
	<bType>*</bType>
	<bType>*</bType>
	<bType>*</bType>
	<bType>*</bType>
	</improper>
</impropers>



</b>

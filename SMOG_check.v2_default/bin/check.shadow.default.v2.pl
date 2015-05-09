#!/usr/bin/perl 


$EXEC_NAME=$ENV{'EXEC_SMOG'};
$TOLERANCE=$ENV{'TOLERANCE'};
$PRECISION=$ENV{'PRECISION'};
##$TEMPLATE_DIR=$ENV{'TEMPLATE_DIR'};
$MAXTHR=1.0+$TOLERANCE;
$MINTHR=1.0-$TOLERANCE;
$BIFSIF=$ENV{'BIFSIF'};
print "environment variables read\n";
print "EXEC_NAME $EXEC_NAME\n";


## this is the all-atom smog check w/o shadow.

$FAILDIR="FAILED.shadow";

##things to do
##  generate all dihedrals based on bonds/angles and make sure they are present
##  check all rigid dihedrals and make sure they are assigned with the right total energy
##  impropers...

$NFAIL=0;
unless( -e $EXEC_NAME){
print "Cant find the READ executable\n";
die;
}

## read in the backbone atom types.  Remember, CA and C1* can be involved in sidechain dihedrals

open(bbamino,"backboneatoms/aminoacids") or die "no amino acid file\n";
while(<bbamino>){
        $LINE=$_;
        chomp($LINE);
        $BBTYPE{$LINE}= "BACKBONE";
}

open(bbnucleic,"backboneatoms/nucleicacids") or die "no amino acid file\n";
while(<bbnucleic>){
        $LINE=$_;
        chomp($LINE);
        $BBTYPE{$LINE}= "BACKBONE";
}

## load information about amino acids, nucleic acids, etc.
#amino acids
open(amino,"residues/aminoacids") or die "no amino acid file\n";
$AAn=0;
while(<amino>){
        $LINE=$_;
        chomp($LINE);
        $TYPE{$LINE}= "AMINO";

        $AA[$AAn]=$LINE;
        $AAn++;
}


#nucleic acids
open(nucleic,"residues/nucleicacids") or die "no nucleic acid file\n";
$NUCLEICn=0;
while(<nucleic>){
        $LINE=$_;
        chomp($LINE);

        $NUCLEIC[$NUCLEICn]=$LINE;
        $NUCLEICn++;

        $TYPE{$LINE}= "NUCLEIC";


}

#ligands
open(ligand,"residues/ligands") or die "no nucleic acid file\n";
$LIGANDn=0;
while(<ligand>){
        $LINE=$_;
        chomp($LINE);
        $TYPE{$LINE}= "LIGAND";
        $LIGANDS[$LIGANDn]=$LINE;
        $LIGANDn++;
}

#ions
open(ion,"residues/ions") or die "no ion file\n";
$IONn=0;
while(<ion>){
        $LINE=$_;
        chomp($LINE);
        $TYPE{$LINE}= "ION";
        $IONS[$IONn]=$LINE;
        $IONn++;
}



## read a file that gives the settings we are going to try.  This will also give the file names.  There will only be 1 pdb that we are going to check. The first line will be the pdb file.


$SETTINGS_FILE=<STDIN>;
chomp($SETTINGS_FILE);
open(PARMS,"$SETTINGS_FILE") or die "The settings file is missing...\n";
while(<PARMS>){
$LINE=$_;
chomp($LINE);
$PDB=$LINE;

                       print "\n*******************************\nSTARTING TESTS for $PDB.pdb\n*******************************\n\n\n";


	$NFAIL=0;
	$FAILED=0;
	$LINE=$_;
	chomp($LINE);
	@A=split(/ /,$LINE);
##	$TOPTEST=$A[11];
	# cutoff distances for protein-protein, protein-nucleic, nucleic-nucleic, molecule-ligand

	# these are not used with the new shadow, but for uniformity, I leave them here.
	$PP_cutoff=4.0;
	$PN_cutoff=4.0;
	$NN_cutoff=4.0;
	$PN_L_cutoff=4.0;

	# minimum sequence distance
	$PP_seq=4;
	$NN_seq=1;


	# ENd of unused stuff

	# energy distributions

	$R_CD=2.0;
	$R_P_BB_SC=2.0;
	$R_N_SC_BB=1.0;

        $PRO_DIH=1.0;
        $NA_DIH=1.0;
        $LIGAND_DIH=1.0;


	# excluded volumes

        $sigma=2.5;
        $epsilon=0.01;

		$sigma=$sigma/10;
		$rep_s12=$sigma**12*$epsilon;
		$sigma=$sigma*10;

	### This settings file is not used.  But, we write it, in case we want information on a test that failed.

        open(READSET,">$PDB.settings") or die  "can not open settings file\n";
        printf READSET ("%s.pdb\n", $PDB);
        printf READSET ("%s.top\n", $PDB);
	if(-e $PDB.top){
		`rm $PDB.top`;
	}
	if(-e $PDB.gro){
		`rm $PDB.gro`;
	}
	if(-e $PDB.ndx){
		`rm $PDB.ndx`;
	}
##	`rm $PDB.top $PDB.gro $PDB.ndx`;
        printf READSET ("%s.gro\n", $PDB);
        printf READSET ("%s.ndx\n", $PDB);
        printf READSET ("%s\n", "All-Atom");
	# do not upload a contact file.
        printf READSET ("%s\n", "CUTOFF");
        printf READSET ("PP_cutoff %s\n", $PP_cutoff);
        printf READSET ("NN_cutoff %s\n", $NN_cutoff);
        printf READSET ("PN_cutoff %s\n", $PN_cutoff);
        printf READSET ("PN_L_cutoff %s\n", $PN_L_cutoff);
        printf READSET ("PP_seq %s\n", $PP_seq);
        printf READSET ("NN_seq %s\n", $NN_seq);
        printf READSET ("R_CD %s\n", $R_CD);
        printf READSET ("R_P_BB_SC %s\n", $R_P_BB_SC);
        printf READSET ("R_N_SC_BB %s\n", $R_N_SC_BB);
        printf READSET ("PRO_DIH %s\n", $PRO_DIH);
        printf READSET ("NA_DIH %s\n", $NA_DIH);
        printf READSET ("LIGAND_DIH %s\n", $LIGAND_DIH);
        printf READSET ("sigma %s\n", $sigma);
        printf READSET ("epsilon %s\n", $epsilon);
        close(READSET);

	## run smog
	
	`$EXEC_NAME -i PDB.files/$PDB.pdb -g $PDB.gro -o $PDB.top -n $PDB.ndx -s $PDB.contacts -tAA $BIFSIF/  &> $PDB.output `;



##run the check script
##
	`bin/top.clean.bash $PDB.ndx $PDB.ndx2`;
	`mv $PDB.ndx2 $PDB.ndx`;

	open(NDX,"$PDB.ndx") or die "no ndx file\n"; 

	while(<NDX>){
		$LINE=$_;        
		chomp($LINE);
		@A=split(/ /,$LINE);
			if($A[0] eq "["){
				$CHAIN=$A[1];
			}else{
				$CID[$LINE]=$CHAIN;
			}
	}

	`bin/top.clean.bash $PDB.top $PDB.top2`;
	`mv $PDB.top2 $PDB.top`;

	open(TOP,"$PDB.top") or die " $PDB.top can not be opened...";

	$DIH_MIN=100000000;
	$DIH_MAX=-100000000;

	close(TOP);



##check the values

	$NCONTACTS=0;

	open(TOP,"$PDB.top") or die " $PDB.top can not be opened...\n";


		while(<TOP>){

			$LINE=$_;
			chomp($LINE);


			@A=split(/ /,$LINE);



## check the excluded volume is consistent with the settings.
                        if($A[1] eq "atomtypes"){
				$EXCL=0;
                                $#A = -1;
                                $LINE=<TOP>;
                                @A=split(/ /,$LINE);

                                until($A[0] eq "["){
					# make sure the ex vol is within 1% of the desired.
                                        if($A[5] < $MINTHR*$rep_s12 || $A[5] > $MAXTHR*$rep_s12){
						$EXCL++;
                                        }
                                        $#A = -1;
                                        $LINE=<TOP>;
                                        @A=split(/ /,$LINE);
                                }

                        }



                        if($A[1] eq "atoms"){
				$NUMATOMS=0;
				$NUMATOMS_LIGAND=0;
                                $#A = -1;
                                $LINE=<TOP>;
                                @A=split(/ /,$LINE);

                                until($A[0] eq "["){
					# store information about each atom

					# atom name
                                        $ATOMNAME[$A[0]]=$A[4];
					# is it a backbone atom?  This list does not include CA and C1* because this classification is only used for determining which bonds are backbone and which are sidechain
					$ATOMTYPE[$A[0]]=$BBTYPE{$A[4]};
					# residue number
                                        $RESNUM[$A[0]]=$A[2];
					# residue name
                                        $RESNAME[$A[0]]=$A[3];
					# nucleic acid, protein, ligand
                                        $MOLTYPE[$A[0]]=$TYPE{$A[3]};

					# see if there are any amino acids, na, or ligands in the system.
					if($MOLTYPE[$A[0]] eq "AMINO"){
						$AMINO_PRESENT=1;
                                                 $NUMATOMS_LIGAND++;

					}elsif($MOLTYPE[$A[0]] eq "NUCLEIC"){
						$NUCLEIC_PRESENT=1;
                                                 $NUMATOMS_LIGAND++;
					}elsif($MOLTYPE[$A[0]] eq "LIGAND"){
                                                $LIGAND_PRESENT=1;
					}elsif($MOLTYPE[$A[0]] eq "ION"){
						$ION_PRESENT=1;

					}else{
                                                print "there is an unrecognized residue name\n";
                                                print "$A[0] $A[3]\n";
                                                die;
                                        }

					$NUMATOMS++;
                                        $#A = -1;
                                        $LINE=<TOP>;
                                        @A=split(/ /,$LINE);
				}

                        }



			# read the bonds.  Make sure they are not assigned twice.  Also, save the bonds, so we can generate all possible bond angles later.
                        if($A[1] eq "bonds"){
                                $#A = -1;
				$#bonds = -1;
				$#bondWatom = -1;
				$#NbondWatom = -1;
				$double_bond=0;
				$bondtype6=0;
				$Nbonds=0;
                                undef %bond_array;
                                $LINE=<TOP>;
                                @A=split(/ /,$LINE);
                                until($A[0] eq "["){
					if($A[2] ==1){				
				
						if($A[0] < $A[1]){
							$string=sprintf("%i-%i", $A[0], $A[1]);
						}else{
							$string=sprintf("%i-%i", $A[1], $A[0]);
						}


					##check if bond has been seen already...
						if($bond_array{$string} != 1){
							## bond was not assigned.
							$bond_array{$string}=1;
							$bonds[$Nbonds][0]=$A[0];
							$bonds[$Nbonds][1]=$A[1];
						##print "$bonds[$Nbonds][0] $bonds[$Nbonds][1]\n";
						# this organization is strange, but it will make sense later...
							$bondWatom[$A[0]][$NbondWatom[$A[0]]]= $Nbonds;
							$bondWatom[$A[1]][$NbondWatom[$A[1]]]= $Nbonds;
							$NbondWatom[$A[0]]++;
							$NbondWatom[$A[1]]++;
							$Nbonds++;
						}else{
						## bond has already been assigned.
							$double_bond++;
						}
					}elsif($A[2] ==6){
						$bondtype6++;
					}
                                	$LINE=<TOP>;
                                	@A=split(/ /,$LINE);

				}
		# generate the angles

				# generate all possible bond angles based on bonds
				undef %theta_gen_as;
				$theta_gen_N=0;
                                $#theta_gen=-1;

				for($i=1;$i<=$NUMATOMS;$i++){
				# go through the atoms.  For each atom, check all of the bonds it is involved in, and see if we can make a bond angle out of it.
				##	print "$NbondWatom[$i]\n";
				        for($j=0;$j<$NbondWatom[$i];$j++){
				                for($k=$j+1;$k<$NbondWatom[$i];$k++){
				                        if($j!=$k){

				                                $A1=$bonds[$bondWatom[$i][$j]][0];
				                                $A2=$bonds[$bondWatom[$i][$j]][1];
				                                $B1=$bonds[$bondWatom[$i][$k]][0];
				                                $B2=$bonds[$bondWatom[$i][$k]][1];
						##		print "$i $j $k $bondWatom[$i][$j] $bondWatom[$i][$k]  $A1 $A2 $B1 $B2\n";
				                                # check the bond angles that can be made
				                                if($A1 == $B1){

				                                        $theta1=$A2;
				                                        $theta2=$A1;
				                                        $theta3=$B2;

				                                }elsif($A1 == $B2){

				                                        $theta1=$A2;
				                                        $theta2=$A1;
				                                        $theta3=$B1;

				                                }elsif($A2 == $B1){

				                                        $theta1=$A1;
				                                        $theta2=$A2;
				                                        $theta3=$B2;

				                                }elsif($A2 == $B2){

				                                        $theta1=$A1;
				                                        $theta2=$A2;
				                                        $theta3=$B1;
	
				                                }


                                				if($theta1 < $theta3){
                                        				$string=sprintf("%i-%i-%i", $theta1, $theta2, $theta3);

                                				}else{
                                        				$string=sprintf("%i-%i-%i", $theta3, $theta2, $theta1);
                                				}

								$theta_gen_as{$string} = 1;
								$theta_gen[$theta_gen_N]="$string";
								##print "$theta_gen[$theta_gen_N]\n";
								$theta_gen_N++;


				                        }
				                }
				        }
				}
			}


                        if($A[1] eq "angles"){
                                $#A = -1;
                                $double_angle=0;
				$Nangles=0;
				$#angles =1;

                                $#angleWatom = -1;
                                $#NangleWatom = -1;
                                $Nangles=0;


                                undef %angle_array;
                                $LINE=<TOP>;
                                @A=split(/ /,$LINE);
                                until($A[0] eq "["){

                                        if($A[0] < $A[2]){
                                                $string=sprintf("%i-%i-%i", $A[0], $A[1], $A[2]);
                                        }else{
                                                $string=sprintf("%i-%i-%i", $A[2], $A[1], $A[0]);
                                        }
						##print "ok $string $A[0] $A[1] $A[2]\n";

					# save the angles
					$angles[$Nangles]="$string";
					##$Nangles++;


                                        ##check if bond has been seen already...
                                        if($angle_array{$string} != 1){
                                                ## bond was not assigned.
                                                $angle_array{$string}=1;

                                                $angles[$Nangles][0]=$A[0];
                                                $angles[$Nangles][1]=$A[1];
                                                $angles[$Nangles][2]=$A[2];
                                                ##print "$angles[$Nangles][0] $angles[$Nangles][1]\n";
                                                # this organization is strange, but it will make sense later...
                                                $angleWatom[$A[0]][$NangleWatom[$A[0]]]= $Nangles;
                                                $angleWatom[$A[1]][$NangleWatom[$A[1]]]= $Nangles;
                                                $angleWatom[$A[2]][$NangleWatom[$A[2]]]= $Nangles;
                                                $NangleWatom[$A[0]]++;
                                                $NangleWatom[$A[1]]++;
                                                $NangleWatom[$A[2]]++;
					$Nangles++;



                                        }else{
                                                ## bond has already been assigned.
                                                $double_angle++;
                                        }

                                        $LINE=<TOP>;
                                        @A=split(/ /,$LINE);

                                }


			## cross-check the angles
				if($theta_gen_N != $Nangles){
				print "the number of generated angles is inconsistent with the number of angles in the top file\n";
				print "$theta_gen_N $Nangles\n";
				}

				$FAIL_angles=0;
				# check to see if all the generated angles (from this script) are present in the top file
				for($i=0;$i<$theta_gen_N;$i++){
						##print "$theta_gen[$i]\n";
					if($angle_array{$theta_gen[$i]} != 1){
						##print "$theta_gen[$i]\n";
						$FAIL_angles++;
						print "generated, but not in top: $theta_gen[$i]\n";
					}
				}

				# check to see if all top angles are present in the generate list.
                                for($i=0;$i<$Nangles;$i++){
                                                ##print "$theta_gen[$i]\n";
                                        if($theta_gen_as{$angles[$i]} != 1){
                                                ##print "$angles[$i]\n";
						print "in top, but not generated: $angles[$i]\n";
						$FAIL_angles++;
                                        }
                                }



                                # generate all possible dihedral angles based on bond angles
                                undef %phi_gen_as;
                                $phi_gen_N=0;
				$Nphi=0;
                                $#phi_gen=-1;
                                undef %improper_gen_as;
                                $improper_gen_N=0;
                                $#improper_gen=-1;

                                for($i=1;$i<=$NUMATOMS;$i++){
                                # go through the atoms.  For each atom, check all of the angles it is involved in, and see if we can make a angle angle out of it.
                                ##      print "$NangleWatom[$i]\n";
                                        for($j=0;$j<$NangleWatom[$i];$j++){
                                                for($k=$j+1;$k<$NangleWatom[$i];$k++){
                                                        if($j!=$k){

                                                                $A1=$angles[$angleWatom[$i][$j]][0];
                                                                $A2=$angles[$angleWatom[$i][$j]][1];
                                                                $A3=$angles[$angleWatom[$i][$j]][2];
                                                                $B1=$angles[$angleWatom[$i][$k]][0];
                                                                $B2=$angles[$angleWatom[$i][$k]][1];
                                                                $B3=$angles[$angleWatom[$i][$k]][2];
								##print "\n";
								##print "$A1 $A2 $A3 $B1 $B2 $B3\n";
                                                ##              print "$i $j $k $angleWatom[$i][$j] $angleWatom[$i][$k]  $A1 $A2 $B1 $B2\n";
                                                                # check the angle angles that can be made
								$formed='not';
                                                                if($A2 == $B1 && $A3 == $B2){

                                                                        $phi1=$A1;
                                                                        $phi2=$A2;
                                                                        $phi3=$A3;
                                                                        $phi4=$B3;
									$formed='proper';

                                                                }elsif($A2 == $B3 && $A3 == $B2){

                                                                        $phi1=$A1;
                                                                        $phi2=$A2;
                                                                        $phi3=$A3;
                                                                        $phi4=$B1;
									$formed='proper';

                                                                }elsif($A2 == $B1  && $A1 == $B2){

                                                                        $phi1=$A3;
                                                                        $phi2=$A2;
                                                                        $phi3=$A1;
                                                                        $phi4=$B3;
									$formed='proper';

                                                                }elsif($A2 == $B3 && $A1 == $B2){

                                                                        $phi1=$A3;
                                                                        $phi2=$A2;
                                                                        $phi3=$A1;
                                                                        $phi4=$B1;
									$formed='proper';

                                                                }elsif($A2 == $B2 && $A1 == $B3){

                                                                        $phi1=$A1;
                                                                        $phi2=$A2;
                                                                        $phi3=$A3;
                                                                        $phi4=$B1;
                                                                        $formed='improper';

                                                                }elsif($A2 == $B2 && $A3 == $B1){

                                                                        $phi1=$B1;
                                                                        $phi2=$B2;
                                                                        $phi3=$B3;
                                                                        $phi4=$A1;
                                                                        $formed='improper';

                                                                }elsif($A2 == $B2 && $A1 == $B1){

                                                                        $phi1=$A1;
                                                                        $phi2=$A2;
                                                                        $phi3=$A3;
                                                                        $phi4=$B3;
                                                                        $formed='improper';

                                                                }elsif($A2 == $B2 && $A3 == $B3){

                                                                        $phi1=$A3;
                                                                        $phi2=$A2;
                                                                        $phi3=$A1;
                                                                        $phi4=$B1;
                                                                        $formed='improper';

                                                                }else{
									$formed="not";
								}


								if($formed eq "proper" ){
	                                                                if($phi1 < $phi4){
        	                                                                $string=sprintf("%i-%i-%i-%i", $phi1, $phi2, $phi3, $phi4);

                	                                                }else{
                        	                                                $string=sprintf("%i-%i-%i-%i", $phi4, $phi3, $phi2, $phi1);
                                	                                }
                                        	                        $phi_gen_as{$string} = 1;
                                                	                $phi_gen[$phi_gen_N]="$string";
								##	print "$string\n";
                                                        	        $phi_gen_N++;
								}elsif($formed eq "improper"){

									$phit[0]=$phi1;
									$phit[1]=$phi2;
									$phit[2]=$phi3;
									$phit[3]=$phi4;


									for($ii=0;$ii<4;$ii++){
										$phi1=$phit[$ii];
										for($jj=0;$jj<4;$jj++){
											if($ii != $jj){
											$phi2=$phit[$jj];
                                                                                		for($kk=0;$kk<4;$kk++){
                                                                                        		if($kk != $jj && $kk != $ii){
	                                                                                       		$phi3=$phit[$kk];
                                                                                                		for($ll=0;$ll<4;$ll++){
                                                                                                        		if($ll != $kk && $ll != $jj && $ll != $ii){
                                                                                                        		$phi4=$phit[$ll];

                                                                        							if($phi1 < $phi4){
                                                                                							$string=sprintf("%i-%i-%i-%i", $phi1, $phi2, $phi3, $phi4);

                                                                        							}else{
                                                                                							$string=sprintf("%i-%i-%i-%i", $phi4, $phi3, $phi2, $phi1);
                                                                        							}
                                                                        							$improper_gen_as{$string} = 1;
                                                                        							$improper_gen[$phi_gen_N]="$string";
                                                                        							$improper_gen_N++;
																##print " $i $j $k $l $improper_gen_N\n";
                                                                                                        		}
	                                                                                               		}
                                                                                        		}
                                                                                		}
											}
										}
									}
								}
                                                        }
                                                }
                                        }
                                }
                        }


			if($A[1] eq "dihedrals"){
				$DENERGY=0;
				$double_dihedral=0;
				$missing_dihedral_3=0;
                                undef %dihedral_array;

				$#A = -1;
				$#ED_T = -1;
				$#EDrig_T = -1;
				$LINE=<TOP>;
				@A=split(/ /,$LINE);
				until($A[0] eq "["){

                                      if($A[0] < $A[3]){
                                                $string=sprintf("%i-%i-%i-%i", $A[0], $A[1], $A[2],  $A[3]);
                                        }else{
                                                $string=sprintf("%i-%i-%i-%i", $A[3], $A[2], $A[1], $A[0]);
                                        }



                                        # save the angles
                                        $phi[$Nphi]="$string";
                                        $Nphi++;



                                        ##check if dihedral has been seen already...
					if($A[7] != 3){
                                        	if($dihedral_array{$string} != 1 ){
                                                	## dihedral was not assigned.
                                                	$dihedral_array{$string}=1;
                                        	}else{
                                                	## dihedral has already been assigned.
							print "dubplicate dihedral: offending dihedral\n $LINE\n";
                                                	$double_dihedral++;
                                        	}
					}else{
						## if it is a type 3 dihedral, then it should have just been set...
                                                if($dihedral_array{$string} != 1 ){
                                                        ## dihedral was not assigned.
							$missing_dihedral_3++;
							print "somehow there is a type 3 dihedral w/o a type 1...\n";
                                                }
                                 


					}


					##print "$B[4], $B[7]\n";
					if($A[4] == 1 && $A[7] == 1 ){
						if($MOLTYPE[$A[0]] ne "LIGAND" ){
							$DENERGY+=$A[6];
						}
						if($A[6]<$DIH_MIN){
							$DIH_MIN=$A[6];
						}
						if($A[6]>$DIH_MAX){
							$DIH_MAX=$A[6];
						}
						## sum energies by dihedral
						if($A[1] > $A[2]){
							$ED_T[$A[2]][$A[1]-$A[2]]+=$A[6];
							$F=$A[2]-$A[1];
							if($F > $DISP_MAX){
								$DISP_MAX=$F;
							}
						}else{
							$ED_T[$A[1]][$A[2]-$A[1]]+=$A[6];
							$F=$A[2]-$A[1];
							if($F > $DISP_MAX){
								$DISP_MAX=$F;
							}
						}
					}

##                                        if($A[4] == 2 && $improper_gen_as{$string} == 1){
##						print "$string\n";

##					}
                                        if($A[4] == 2 && $improper_gen_as{$string} != 1){

                                                if($A[1] > $A[2]){
                                                        $F=$A[1]-$A[2];
							$EDrig_T[$A[2]][$A[1]-$A[2]]+=$A[6];

						}else{
                                                        $F=$A[2]-$A[1];
							$EDrig_T[$A[1]][$A[2]-$A[1]]+=$A[6];
						}

                                                if($F > $DISP_MAX){
							$DISP_MAX=$F;
						}

					}




					$#A = -1;
	                                $LINE=<TOP>;
        	                        @A=split(/ /,$LINE);


				}


                                $FAIL_phi=0;
                                # check to see if all the generated dihedrals (from this script) are present in the top file
                                for($i=0;$i<$phi_gen_N;$i++){
                                                ##print " $i $phi_gen[$i]\n";
                                                ##print "$theta_gen[$i]\n";
                                        if($dihedral_array{$phi_gen[$i]} != 1){
                                                ##print "$theta_gen[$i]\n";
                                                $FAIL_phi++;
						print "Generated dihedral is not in the list of included dihedrals...\n";
                                                print "$FAIL_phi $i $phi_gen[$i] $dihedral_array{$phi_gen[$i]}\n";
                                        }
                                }

                                # check to see if all top dihedrals are present in the generate list.
                                for($i=0;$i<$Nphi;$i++){
                                                ##print "$theta_gen[$i]\n";
                                                ##print " $i $phi[$i]\n";
#                                        if( $improper_gen_as{$phi[$i]} == 1 ){
#						print "improper detected\n";
#					}
					
                                        if($phi_gen_as{$phi[$i]} != 1 && $improper_gen_as{$phi[$i]} != 1 ){
                                                ##print "$angles[$i]\n";
                                                $FAIL_phi++;
						print "An included dihedral can not be found in the list of generated ones...";
						print "$FAIL_phi, $i, $phi[$i]\n"
					##	print "ok\n";
                                      }
                               }



			}


##                        if($A[1] eq "atoms"){


##			}


			# check values for contact energy
                        if($A[1] eq "pairs"){
				# reset all the values because we can analyze multiple settings, and we want to make sure we always start at 0 and with arrays cleared.
				$stackingE=0;
				$NonstackingE=0;
                                $CONTENERGY=0;
				$FAILSTACK=0;
				$FAILNONSTACK=0;
				$longcontact=0;
                                $#A = -1;
                                $LINE=<TOP>;
                                @A=split(/ /,$LINE);
	                        until($A[0] eq "["){
					$PAIRS[$NCONTACTS][0]=$A[0];
					$PAIRS[$NCONTACTS][1]=$A[1];
					$NCONTACTS++;
					# determine the epsilon of the contact
                                        $W=($A[3]*$A[3])/(4*$A[4]);
                                        $sigma=($A[4]/(2*$A[3]))**(1.0/6.0);
					if($sigma > 0.6){
						print "long contacts! distance $sigma nm.\n";
						print "$LINE";
		                                $longcontact++;

					}
					## so long as the contacts are not with ligands, then we add the sum
					if($MOLTYPE[$A[0]] ne "LIGAND" and $MOLTYPE[$A[1]] ne "LIGAND"){
                                        $CONTENERGY+=($A[3]*$A[3])/(4*$A[4]);
                                        $sigma=($A[4]/(2*$A[3]))**(1.0/6.0);
					}

					# truncate the epsilon, for comparison purpsoses later.
                                        $W=int(($W * $PRECISION))/($PRECISION*1.0);
					# check to see if the contact is nucleic acids, adjacent residues and not backbone atoms.  These should be rescaled by a factor of 1/3
					if($MOLTYPE[$A[0]] eq "NUCLEIC" and $MOLTYPE[$A[1]] eq "NUCLEIC" and $ATOMTYPE[$A[0]] ne "BACKBONE" and  $ATOMTYPE[$A[1]] ne "BACKBONE" and $ATOMNAME[$A[0]] ne "C1\*" and $ATOMNAME[$A[1]] ne "C1\*" and abs($RESNUM[$A[0]]-$RESNUM[$A[1]]) == 1 and $CID[$A[0]] == $CID[$A[1]]){

						# if we haven't assigned a value to stacking interactions, then let's save it
						# if we have saved it, check to see that this value is the same as the previous ones.
						if($stackingE == 0 ){
							$stackingE=$W;
						}elsif(abs($stackingE - $W) > 10.0/($PRECISION*1.0) ){
							$FAILSTACK++;
							print "$stackingE  $W $A[0] $A[1] \n";
						}
					}else{
					# it is not a stacking contact.  Do the same checks for non-stacking interactions
                                                if($NonstackingE == 0 ){
                                                        $NonstackingE=$W;
                                                }elsif(abs($NonstackingE - $W) > 10.0/($PRECISION*1.0) ){
                                                        $FAILNONSTACK++;
							print "$NonstackingE $W\n";
                                                }       
					}
					# read the next line
                                        $#A = -1;
                                        $LINE=<TOP>;
                                        @A=split(/ /,$LINE);
                                }

                        }


                        if($A[1] eq "exclusions"){
                                $#A = -1;
                                $LINE=<TOP>;
                                @A=split(/ /,$LINE);
				$NEXCL=0;
				$FAILEXCLUSIONS=0;
                                until($A[0] eq "["){

					if($PAIRS[$NEXCL][0] != $A[0] || $PAIRS[$NEXCL][1] != $A[1]){
						$FAILEXCLUSIONS++;
						print "FAIL: mis-match between pairs and exclusions (pair $NEXCL)\n";
						print "pair: $PAIRS[$NEXCL][0] $PAIRS[$NEXCL][1]\n";
						print "excl: $A[0] $A[1]\n";
					}
					$NEXCL++;
					# read the next line
                                        $#A = -1;
                                        $LINE=<TOP>;
                                        @A=split(/ /,$LINE);

				}
				print "checking number of contacts and exclusions match...\n";
				if($NEXCL == $NCONTACTS){
					print "$NEXCL $NCONTACTS PASSED\n";
				}else{
					print "FAILED\n";
					$FAILEXCLUSIONS++;
				}



			}



		}




		## check stuff
			print "number of atoms = $NUMATOMS\n";
			print "number of atoms(excluding ligands) = $NUMATOMS_LIGAND\n";
			print "Dihedral energy = $DENERGY\n";
			print "Contact energy = $CONTENERGY\n";
			print "max dihedral = $DIH_MAX\n";
			print "min dihedral = $DIH_MIN\n";

			print "generated angles, dihedrals, impropers\n";
			print "$theta_gen_N $phi_gen_N $improper_gen_N\n";
			if($theta_gen_N == 0 || $phi_gen_N == 0 ||  $improper_gen_N == 0){
				print "couldnt generate something....\n";
				$FAILED++;
			}

                        if($EXCL > 0){
				print "FAILED: excluded volume\n";
                                $FAILED++;
			}else{
                                 print "excluded volume:PASSED\n";
                        }


			$D_R=$DIH_MAX/ $DIH_MIN;

        ##printf READSET ("%s\n", $R_N_SC_DD);
			## check the energy per dihedral and where the dihedral is SC/BB NA/AMINO
			$PBBfail=0;
			$PSCfail=0;
			$NABBfail=0;
			$NASCfail=0;
			$PBBvalue=0;	
			$PSCvalue=0;	
			$NABBvalue=0;	
			$NASCvalue=0;
			$rigid_fail=0;
			$NUM_NONZERO=0;
                        $LIGdfail=0;
                        $LIGdvalue=0;
	
			for($i=0;$i<$NUMATOMS+1;$i++){
				for($j=0;$j<=$DISP_MAX;$j++){
##					print "$i $j $ED_T[$i][$j]\n";

					if($EDrig_T[$i][$j] > 0){
						$NUM_NONZERO++;	


						##print "$i $j $EDrig_T[$i][$j]\n";

						if( ($ATOMNAME[$i] eq "C"  && $ATOMNAME[$i+$j] eq "N") || (  $ATOMNAME[$i] eq "N"  && $ATOMNAME[$i+$j] eq "C"   )){
							if( abs($EDrig_T[$i][$j]-10.0) > 0.1 ){
								print "weird omega rigid...\n";
								print "$i $j $EDrig_T[$i][$j]\n";
                                        			print "$ATOMNAME[$i] $ATOMNAME[$i+$j]\n"; 
                                        			print "$RESNUM[$i] $RESNUM[$i+j]\n\n";
								$rigid_fail++;	
							}
#else{
#								print "backbone passed\n"; 
#							}
						}else{

                                                        if(abs($EDrig_T[$i][$j]-40.0) > 0.1 ){
                                                                print "weird ring dihedral...\n";
                                                                print "$i $j $EDrig_T[$i][$j]\n";
                                                                print "$ATOMNAME[$i] $ATOMNAME[$i+$j]\n";
                                                                print "$RESNUM[$i] $RESNUM[$i+j]\n\n";
                                                                $rigid_fail++;
                                                        }
#else{
 #                                                               print "ring passed\n";
  #                                                      }

						}
					}

					if($ED_T[$i][$j] > 0){
						$ED_T[$i][$j]= int(($ED_T[$i][$j] * $PRECISION))/($PRECISION*1.0) ;

						if($MOLTYPE[$i] eq "AMINO"){
							if($ATOMTYPE[$i] eq "BACKBONE" or  $ATOMTYPE[$i+$j] eq "BACKBONE"){
								$DIH_TYPE[$i][$j]="AMINOBB";

								if($PBBvalue !=$ED_T[$i][$j] && $PBBvalue !=0){
									print "FAILED: protein backbone dihedral $i $j\n";
									print "$PBBvalue is before\n";
									print "$ED_T[$i][$j]  is the bad one...\n";
									$PBBfail++;
								}
								$PBBvalue=$ED_T[$i][$j];
							}else{
								$DIH_TYPE[$i][$j]="AMINOSC";
								if($PSCvalue !=$ED_T[$i][$j] && $PSCvalue !=0){
									$PSCfail++;
									print "FAILED: protein sidechain dihedral $i $j\n";
									print "$PSCvalue is before\n";
									print "$ED_T[$i][$j] $i $j is the bad one...\n";
								}
								$PSCvalue=$ED_T[$i][$j];
							}
						}elsif($MOLTYPE[$i] eq "NUCLEIC"){
                                                        if($ATOMTYPE[$i] eq "BACKBONE" or  $ATOMTYPE[$i+$j] eq "BACKBONE"){
                                                                $DIH_TYPE[$i][$j]="NUCLEICBB";
								if($NABBvalue !=$ED_T[$i][$j] && $NABBvalue != 0 ){
									$NABBfail++;
									print "FAILED: nucleic backbone dihedral $i $j\n";
									print "$NABBvalue is before\n";
									print "$ED_T[$i][$j] is the bad one...\n";
								}
								$NABBvalue=$ED_T[$i][$j];
                                                        }else{
                                                                $DIH_TYPE[$i][$j]="NUCLEICSC";
								if($NASCvalue !=$ED_T[$i][$j] && $NASCvalue !=0){
									$NASCfail++;
									print "FAILED: nucleic sidechain dihedral $i $j\n";
									print "$NASCvalue is before\n";
									print "$ED_T[$i][$j] is the bad one...\n";
								}
								$NASCvalue=$ED_T[$i][$j];
                                                        }
						}elsif($MOLTYPE[$i] eq "LIGAND"){
                                                         $DIH_TYPE[$i][$j]="LIGAND";
                                                                if($LIGdvalue !=$ED_T[$i][$j] && $LIGdvalue != 0 ){
                                                                        $LIGdfail++;
                                                                        print "backbone atom $i $j failed\n";
                                                                        print "$LIGdvalue is before\n";
                                                                        print "$ED_T[$i][$j] is the bad one...\n";
                                                                }
                                                                $LIGdvalue=$ED_T[$i][$j];
                                                }



					##	$V= int(($ED_T[$i][$j] * 1000))/1000.0 ;
				##		print "$i $j $ED_T[$i][$j] $DIH_TYPE[$i][$j]\n";
					}
				}

			}





#                        if($SHADOWFINISHED!=1){
#                                print "FAIL: Shadow did not finish\n";
#                                $FAILED++;
#                        }else{
#                                print "PASS: Shadow finish\n";
#
#                        }


			print "$NUM_NONZERO rigid dihedrals are identified\n";

                        if($double_bond >0){
                                print "Some bonds were assigned more than once\n";
                                $FAILED++;
                        }else{
                                print "duplicate bonds...: PASSED\n";
                        }

                        if($double_angle >0){
                                print "Some angles were assigned more than once\n";
                                $FAILED++;
                        }else{
                                print "duplicate angles...: PASSED\n";
                        }


                        if($FAIL_angles >0){
                                print "Something funny with the angles... not consistent between script and top.\n";
                                $FAILED++;
                        }else{
                                print "bond angles...: PASSED\n";
                        }


                        if($FAIL_phi >0){
                                print "Something funny with the dihedral angles... not consistent between script and top.\n";
                                $FAILED++;
                        }else{
                                print "dihedral angles...: PASSED\n";
                        }
			
			if($rigid_fail >0){
                                print "Rigid dihedrals do not have the correct strengths\n";
                                $FAILED++;
			}else{
				print "strength of rigid dihedrals: PASSED\n";
			}


                        if($double_dihedral >0){
                                print "Some dihedral were assigned more than once\n";
                                $FAILED++;
                        }else{
                                print "duplicate dihedrals...: PASSED\n";
                        }


                        if($missing_dihedral_3 >0){
                                print "A type 3 dihedral was present without a type 1...\n";
                                $FAILED++;
                        }else{
                                print "Type-3 dihedrals...: PASSED\n";
                        }


			if($PBBfail >0){
				print "FAILED: $PBBfail protein backbone dihedrals dont have the same values...\n";
				$FAILED++;
			}else{
				print "protein backbone dihedrals: PASSED\n";
			}
			if($PSCfail >0){
				print "FAILED: $PSCfail protein sidechain dihedrals dont have the same values...\n";
				$FAILED++;
			}else{
                                print "protein sidechain dihedrals: PASSED\n";
                        }

			if($NABBfail >0){
				print "FAILED: $NABBfail nucleic acid backbone dihedrals dont have the same values...\n";
				$FAILED++;
			}else{
                                print "NA backbone dihedrals: PASSED\n";
                        }


			if($NASCfail >0){
				print "FAILED: $NASCfail nucleic acid sidechain dihedrals dont have the same values...\n";
				$FAILED++;
			}else{
                                print "NA sidechain dihedrals: PASSED\n";
                        }

			if($longcontact>0){
				print "contacts were too long!!!  FAILED.\n";
				$FAILED++;
			}else{
				print "contact distances: PASSED\n";
			}


			if($stackingE ==0){
				print "no stacking interactions with these parameters\n";
			}elsif($FAILSTACK >0){
				print "stacking interactions are not all the same value\n";
				$FAILED++;
			}else{
                                print "stacking interactions: PASSED\n";
                        }


			if($NonstackingE ==0){
				print "no non-stacking interactions with these parameters\n";
			}elsif($FAILNONSTACK >0){
				print "non-stacking interactions are not all the same value\n";
				$FAILED++;
			}else{
                                print "non-stacking interactions: PASSED\n";
                        }

			if($NonstackingE !=0 && $stackingE !=0){

				$CR=$NonstackingE/$stackingE;
				if($CR > 1.02 || $CR < 0.98){
					print "ratio between stacking and non stacking is not 1\n";
					print "ratio is $CR\n";
					$FAILED++;
				}else{
					print "ratio between stacking and non-stacking: PASSED\n";
				}
			}

			if($AMINO_PRESENT){
					print "protein dihedral BB, SC values: $PBBvalue $PSCvalue\n";
				if($R_P_BB_SC*$MAXTHR > $PBBvalue/$PSCvalue && $R_P_BB_SC*$MINTHR < $PBBvalue/$PSCvalue){
					print "protein dihedral ratio: PASSED\n";
				}else{
					print "protein dihedral ratio: FAILED\n";
					$FAILED++;
				}
			}

                        if($NUCLEIC_PRESENT){
                                        print "nucleic dihedral BB SC values: $NABBvalue $NASCvalue\n";
                                if($R_N_SC_BB*$MAXTHR > $NASCvalue/$NABBvalue && $R_N_SC_BB*$MINTHR < $NASCvalue/$NABBvalue){
                                        print "nucleic dihedral ratio: PASSED\n";
                                }else{
                                        print "nucleic dihedral ratio: FAILED\n";
                                        $FAILED++;
                                }
                        }

                        if($LIGAND_PRESENT){

                                if($LIGdfail > 0){
                                        print "ligand dihedrals, contant value: FAILED\n";
                                        $FAILED++;

                                }else{
                                        print "ligand dihedrals, contant value: PASSED\n";

                                }

                        }

                        if($AMINO_PRESENT && $NUCLEIC_PRESENT){
                                        print "protein: $PBBvalue nucleic acid: $NABBvalue\n";

                                        $RR=$PBBvalue/$NABBvalue;
                                        print "$PBBvalue $NABBvalue\n";
                                        $RR_TARGET=$PRO_DIH/$NA_DIH;
                                        print "$PRO_DIH $NA_DIH\n";
                                        print "Target ratio: $RR_TARGET\n";
                                        print "Actual ratio: $RR\n";
                                if($RR > $MAXTHR*$RR_TARGET || $RR < $MINTHR*$RR_TARGET){
                                #if($PBBvalue/$NABBvalue > $MAXTHR*$PRO_DIH/$NA_DIH || $PBBvalue/$NABBvalue < $MINTHR*$PRO_DIH/$NA_DIH){
                                        print "backbone dihedrals are not consistent between nucleic acids and protein: FAILED\n";
                                        print "Target $RR_TARGET Actual $RR \n";
                                        $FAILED++;

                                }else{

                                        print "consistency between NA-protein backbone dihedrals: PASSED\n";

                                }


                        }


                        if($AMINO_PRESENT && $LIGAND_PRESENT){
                                        print "protein: $PBBvalue Ligand: $LIGdvalue\n";

                                        $RR=$PBBvalue/$LIGdvalue;
                                        $RR_TARGET=$PRO_DIH/$LIGAND_DIH;
                                        print "Target ratio: $RR_TARGET\n";
                                        print "Actual ratio: $RR\n";
                                if($RR > $MAXTHR*$RR_TARGET || $RR < $MINTHR*$RR_TARGET){

#                                if($PBBvalue/$LIGdvalue > $MAXTHR*$PRO_DIH/$LIGAND_DIH || $PBBvalue/$LIGdvalue < $MINTHR*$PRO_DIH/$LIGAND_DIH){
                                        print "backbone dihedrals are not consistent between ligands and protein: FAILED\n";
                                        print "Target $RR_TARGET Actual $RR \n";
                                        $FAILED++;

                                }else{

                                        print "consistency between ligand-protein backbone dihedrals: PASSED\n";

                                }


                        }


                        if($LIGAND_PRESENT && $NUCLEIC_PRESENT){
                                        print "ligand: $LIGdvalue nucleic acid: $NABBvalue\n";
                                        $RR=$LIGdvalue/$NABBvalue;
                                        $RR_TARGET=$LIGAND_DIH/$NA_DIH;
                                        print "Target ratio: $RR_TARGET\n";
                                        print "Actual ratio: $RR\n";
                                if($RR > $MAXTHR*$RR_TARGET || $RR < $MINTHR*$RR_TARGET){
                                        print "backbone dihedrals are not consistent between nucleic acids and ligand: FAILED\n";
                                        print "Target $RR_TARGET Actual $RR \n";
                                        $FAILED++;

                                }else{

                                        print "consistency between NA-ligand backbone dihedrals: PASSED\n";

                                }


                        }


			## check if the range of dihedrals is reasonable  NEED TO UPDATE TO HANDLE RNA ratio and protein ratio...
			if($D_R > $MAXTHR*4*$R_P_BB_SC  ){
				print "WARNING!!!: range of dihedrals is large\n";
				##$FAILED++;
			}else{
				print "PASSED: range of dihedrals ok\n";

			}
			##	print "ratio $D_R\n";
		$CD_ratio=$CONTENERGY/$DENERGY;


		if($MAXTHR*$R_CD < $CD_ratio || $MINTHR*$R_CD > $CD_ratio){

		print "The contact/dihedral ratio: FAILED\n";
				$FAILED++;

		}else{
		print "The contact/dihedral ratio: PASSED\n";
		}



	        open(CFILE,"$PDB.contacts") or die "can\'t open $PDB.contacts\n";
	        $NUMBER_OF_CONTACTS_SHADOW=0;
	        while(<CFILE>){
	        $NUMBER_OF_CONTACTS_SHADOW++;
	        }

		if($FAILEXCLUSIONS > 0){
			print "exclusion-pair matching: FAILED\n";
			$FAILED++;
		}else{
			print "exclusion-pair matching: PASSED\n";
		}


               if($NUMBER_OF_CONTACTS_SHADOW != $NCONTACTS+$bondtype6){
	               $FAILED++;
                       print "Same number of contacts not found in contact file and top file!!!! FAIL\n";
                       printf ("%i contacts were found in the contact file.\n", $NUMBER_OF_CONTACTS_SHADOW);
			$NRDFFF=$NCONTACTS+$bondtype6;
                       printf ("%i contacts were found in the top file.\n", $NRDFFF);
               }


		print "target $R_CD actual $CD_ratio\n";

		$E_TOTAL=$DENERGY+$CONTENERGY;

		$CTHRESH=$NUMATOMS*10.0/$PRECISION;
		##print "$CTHRESH\n";

		if(abs($NUMATOMS_LIGAND-$E_TOTAL) > $CTHRESH){
		print "The total energy: FAILED\n";
				$FAILED++;
		}else{
		
		print "The total energy: PASSED\n";

		}

		print "number of non-ligand atoms $NUMATOMS_LIGAND total E $E_TOTAL\n";





                if($FAILED > 0){
                        print "\n*********************************\n $FAILED TESTS FAILED!!!\n*********************************\n\n";
                        print "saving files with names $PDB.fail$NFAIL.X\n";
                        `mv $PDB.top $FAILDIR/$PDB.fail$NFAIL.top`;
                        `cp $PDB.pdb $FAILDIR/$PDB.fail$NFAIL.pdb`;
                        `mv $PDB.gro  $FAILDIR/$PDB.fail$NFAIL.gro`;
                        `mv $PDB.ndx  $FAILDIR/$PDB.fail$NFAIL.ndx`;
                        `mv $PDB.settings  $FAILDIR/$PDB.fail$NFAIL.settings`;
                        `mv $PDB.contacts  $FAILDIR/$PDB.fail$NFAIL.contacts`;
                        `mv $PDB.output  $FAILDIR/$PDB.fail$NFAIL.output`;
#			`mv temp.bifsif $FAILDIR/$PDB.fail$NFAIL.bifsif`;
                        $NFAIL++;
                        $FAIL_SYSTEM++;
                }else{
                        print "\n*******************************\nPASSED\n*******************************\n\n\n";

                        `rm $PDB.top $PDB.gro $PDB.ndx $PDB.settings $PDB.output`;

##                      `rm $PDB.top $PDB.gro $PDB.ndx $PDB.settings`;
                }

}


                if($FAIL_SYSTEM > 0){
                        print "\n*********************************\n TESTS FAILED  !!!\n*********************************\n\n";

                }else{
                        print "\n************************\nPASSED ALL BASIC TESTS FOR ALL-ATOM MODEL\n****************************\n\n\n";


##                      `rm $PDB.top $PDB.gro $PDB.ndx $PDB.settings`;
                }


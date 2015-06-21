#!/usr/bin/perl 
use strict;
use warnings;
# This is the main script that runs SMOG2 and then checks to see if the generated files are correct.
# This is intended to be a brute-force evaluation of everything that should appear. Since this is
# a testing script, it is not designed to be efficient, but to be thorough, and foolproof...


print <<EOT;
*****************************************************************************************
                                       smog-check                                   

       smog-check is part of the SMOG v2 distribution, available at smog-server.org     

       This tool will check your installation of SMOG v2, to ensure that a range of
                         models are being constructed properly.

                       See the SMOG manual for usage guidelines.

            For questions regarding this script, contact info\@smog-server.org              
*****************************************************************************************
EOT


 
our $EXEC_NAME=$ENV{'smog_exec'};
our $SMOGDIR=$ENV{'SMOG_PATH'};
our $SCM="$SMOGDIR/tools/SCM.jar";
our $TOLERANCE=$ENV{'TOLERANCE'};
our $MAXTHR=1.0+$TOLERANCE;
our $MINTHR=1.0-$TOLERANCE;
our $PRECISION=$ENV{'PRECISION'};
#these are variables used for default testing
our $BIFSIF_AA=$ENV{'BIFSIF_AA_DEFAULT'};
our $BIFSIF_CA=$ENV{'BIFSIF_CA_DEFAULT'};
#these are variables used for non-default testing
our $TEMPLATE_DIR_AA=$ENV{'BIFSIF_AA_TESTING'};
our $TEMPLATE_DIR_AA_STATIC=$ENV{'BIFSIF_STATIC_TESTING'};
our $TEMPLATE_DIR_CA=$ENV{'BIFSIF_CA_TESTING'};

unless(-d $BIFSIF_AA && -d $BIFSIF_CA && -d $TEMPLATE_DIR_AA && -d $TEMPLATE_DIR_AA_STATIC && -d $TEMPLATE_DIR_CA ){
 print "Can\'t find the template directories. Something is wrong with the configurations of this script.\n";
 print "Your intallation of SMOG2 may be ok, but we can\'t tell\n";
 print "Giving up...\n";
 die;
}

# default location of test PDBs
our $PDB_DIR="share/PDB.files";
print "environment variables read\n";
print "EXEC_NAME $EXEC_NAME\n";

## this is the all-atom smog check with shadow.
our $FAILDIR="FAILED";


sub internal_error
{
 my ($MESSAGE)=@_;
 chomp($MESSAGE);
  print "Internal error at $MESSAGE\n";
  print "Please report this to info\@smog-server.org\n";
  print "Quitting.\n";
  exit;
}


our @FILETYPES=("top","gro","ndx","settings","contacts","output","contacts.SCM");

unless( -e $SCM){
 print "Can\'t find Shadow! Quitting!!\n";
 exit;
}
our %BBTYPE;
## read in the backbone atom types.  Remember, CA and C1* can be involved in sidechain dihedrals
open(BBAMINO,"share/backboneatoms/aminoacids") or die "no amino acid file\n";
while(<BBAMINO>){
 my $LINE=$_;
 chomp($LINE);
 $LINE =~ s/\s+$//;
 $BBTYPE{$LINE}= "BACKBONE";
}

open(BBNUCLEIC,"share/backboneatoms/nucleicacids") or die "no amino acid file\n";
while(<BBNUCLEIC>){
 my $LINE=$_;
 chomp($LINE);
 $LINE =~ s/\s+$//;
 $BBTYPE{$LINE}= "BACKBONE";
}
our %TYPE;
my @AA;
## LOAD INFORMATION ABOUT WHAT TYPES OF RESIDUES ARE RECOGNIZED BY SMOG2
#amino acids
open(AMINO,"share/residues/aminoacids") or die "no amino acid file\n";
my $AAn=0;
while(<AMINO>){
 my $LINE=$_;
 chomp($LINE);
 $LINE =~ s/\s+$//;
 $TYPE{$LINE}= "AMINO";
 $AA[$AAn]=$LINE;
 $AAn++;
}


#nucleic acids
open(NUCLEIC,"share/residues/nucleicacids") or die "no nucleic acid file\n";
my $NUCLEICn=0;
my @NUCLEIC;
while(<NUCLEIC>){
 my $LINE=$_;
 chomp($LINE);
 $LINE =~ s/\s+$//;
 $NUCLEIC[$NUCLEICn]=$LINE;
 $NUCLEICn++;
 $TYPE{$LINE}= "NUCLEIC";
}

#ligands
open(LIGAND,"share/residues/ligands") or die "no nucleic acid file\n";
my $LIGANDn=0;
my @LIGANDS;
while(<LIGAND>){
 my $LINE=$_;
 chomp($LINE);
 $LINE =~ s/\s+$//;
 $TYPE{$LINE}= "LIGAND";
 $LIGANDS[$LIGANDn]=$LINE;
 $LIGANDn++;
}

#ions
open(ION,"share/residues/ions") or die "no ion file\n";
my $IONn=0;
my @IONS;
while(<ION>){
 my $LINE=$_;
 chomp($LINE);
 $LINE =~ s/\s+$//;
 $TYPE{$LINE}= "ION";
 $IONS[$IONn]=$LINE;
 $IONn++;
}

## READ IN THE LIST OF TEST PDBs.
## We will generate SMOG2 models and then check to see if the top files are correct for the default model
# we are a bit lazy, and will just use global variables
my $FAIL_SYSTEM=0;
our $default;
our $model;
our $PDB;
our $CONTTYPE;
our $CONTD;
our $CONTR;
our $BBRAD;
our $R_CD;
our $R_P_BB_SC;
our $R_N_SC_BB;
our $PRO_DIH;
our $NA_DIH;
our $LIGAND_DIH;
our $sigma;
our $epsilon;
our $epsilonCAC;
our $epsilonCAD;
our $sigmaCA;
our $FAILED;
our @CID;
our $DIH_MIN;
our $DIH_MAX;
our $NCONTACTS;
our $NUMATOMS;
our $NUMATOMS_LIGAND;
our $NUCLEIC_PRESENT;
our $AMINO_PRESENT;
our $LIGAND_PRESENT;
our $ION_PRESENT;
our @FIELDS;
our @FAILLIST = ('MASS', 'CHARGE', 'PARTICLE', 'C6 VALUES', 'C12 VALUES', 'SUPPORTED BOND TYPES', 'GRO-TOP CONSISTENCY', 'BOND STRENGTHS', 'ANGLE TYPES', 'ANGLE WEIGHTS', 'DUPLICATE BONDS', 'DUPLICATE ANGLES', 'ANGLE CONSISTENCY', 'IMPROPER WEIGHTS', 'CA DIHEDRAL WEIGHTS', 'DUPLICATE TYPE 1 DIHEDRALS','DUPLICATE TYPE 2 DIHEDRALS','DUPLICATE TYPE 3 DIHEDRALS','1-3 DIHEDRAL PAIRS','3-1 DIHEDRAL PAIRS','doubledih', 'W3', 'S3', 'A3', 'check13', 'phi', 'STACK', 'NONSTACK', 'LONGCONT', 'CONTACT', 'ContactDist', 'EXCLUSIONS', 'BOX');
our %FAIL;


our $FAIL_W3;
our $FAIL_S3;
our $FAIL_A3;
our $FAIL_phi;
our $FAIL_STACK;
our $FAIL_NONSTACK;
our $FAIL_LONGCONT;
our $FAIL_CONTACT;
our $FAIL_ContactDist;
our $FAIL_EXCLUSIONS;
our $rep_s12;
our @ATOMNAME;
our @GRODATA;
our @ATOMTYPE;
our @RESNUM;
our @MOLTYPE;
our $bondEps;
our $bondMG;
our $angleEps;
our $ringEps;
our $omegaEps;
our $impEps;
our $contacts;
our $DENERGY;
our @ED_T;
our @EDrig_T;
our $DISP_MAX=0;
our $CONTENERGY;
our ($theta_gen_N,$phi_gen_N,$improper_gen_N);
our ($NonstackingE,$stackingE);
our @XT;
our @YT;
our @ZT;
our $bondtype6;

my $SETTINGS_FILE=<STDIN>;
chomp($SETTINGS_FILE);
open(PARMS,"$SETTINGS_FILE") or die "The settings file is missing...\n";
my $TESTNUM=0;
## Run tests for each pdb
my $NFAIL=0;
while(<PARMS>){
 my $LINE=$_;
 chomp($LINE);
 $LINE =~ s/\s+$//;
 $FAILED=0;
 $LINE=$_;
 chomp($LINE);
 $LINE =~ s/\s+$//;
 my @A=split(/ /,$LINE);
 $PDB=$A[0];
 $TESTNUM++;
 unless(-e "$PDB_DIR/$PDB.pdb"){
  print "Unable to find PDB file $PDB_DIR/$PDB.pdb for testing.  Skipping this test\n";
  $FAIL_SYSTEM++;
  next;
 }
  print "\n*************************************************************\n";
  print "                 STARTING TEST $TESTNUM ($PDB)\n";
  print "*************************************************************\n";
 
## These next few lines are currently obsolete, since we are only testing the SHADOW map
## they are left in for future extentions to cut-off maps

 $model=$A[1];
 if($A[2] =~ m/default/){
  $default="yes";
 }else{
  $default="no";
 }
 if($model =~ m/CA/){
  print "Testing CA model\n";
 }elsif($model =~ m/AA/){
  print "Testing AA model\n";
 }else{
  print "Model name $model, not understood. Only CA and AA models are supported by the test script.  Quitting...\n";
  exit;
 }

 if($default eq "yes"){
  print "checking default parameters\n";
  # energy distributions

  ## Settings relevant for the default model
  $CONTTYPE="shadow";
  $CONTD=6.0;
  $CONTR=1.0;
  $BBRAD=0.5;
  $R_CD=2.0;
  $R_P_BB_SC=2.0;
  $R_N_SC_BB=1.0;
  $PRO_DIH=1.0;
  $NA_DIH=1.0;
  $LIGAND_DIH=1.0;
  $sigma=2.5;
  $epsilon=0.01;
  $epsilonCAC=1.0;
  $epsilonCAD=1.0;
  $sigmaCA=4.0;
 }else{
  print "checking non-default parameters for SMOG models\n";
  my $ARG=2;
  # energy distributions
  # map type
  my $CONTTYPE=$A[$ARG];
  $ARG++;
  if($CONTTYPE =~ m/shadow/){
   $CONTD=$A[$ARG];
   $ARG++;
   $CONTR=$A[$ARG];
   $ARG++;
   $BBRAD=0.5;
  }elsif($CONTTYPE =~ m/cutoff/){
   $CONTD=$A[$ARG];
   $ARG++;
   $CONTR=0;
   $BBRAD=0.0;
  }else{
   print "Contact scheme $CONTTYPE is not supported. This is a mistake in the test suite.  Quitting...\n";
   exit;
  }

   #if shadow, read length and size
  # if cutoff, just read length
  $R_CD=$A[$ARG];
   $ARG++;
  $R_P_BB_SC=$A[$ARG];
   $ARG++;
  $R_N_SC_BB=$A[$ARG];
   $ARG++;
  $PRO_DIH=$A[$ARG];
   $ARG++;
  $NA_DIH=$A[$ARG];
   $ARG++;
  $LIGAND_DIH=$A[$ARG];
   $ARG++;
  # excluded volumes
  $sigma=$A[$ARG];
   $ARG++;
  $epsilon=$A[$ARG];
   $ARG++;
  $epsilonCAC=$A[$ARG];
   $ARG++;
  $epsilonCAD=$A[$ARG];
   $ARG++;
  $sigmaCA=$A[$ARG];
   $ARG++;
 }
 $bondEps=20000;
 $bondMG=200;
 $angleEps=40;
 $ringEps=40;
 $omegaEps=10;
 $impEps=10;
 $contacts="shadow";

 &smogchecker;


}

 # If any systems failed, output message
 if($FAIL_SYSTEM > 0){
  print "\n*************************************************************\n";
  print "                     TESTS FAILED: CHECK MESSAGES ABOVE  !!!\n";
  print "*************************************************************\n";
 
 }else{
  print "\n*************************************************************\n";
  print "                     PASSED ALL TESTS  !!!\n";
  print "*************************************************************\n";
 }

sub smogchecker
{

 ### Going to add if statements for any CA-only, or AA-only calculations
 
 &preparesettings;
 
 # RUN SMOG2
 if($default eq "yes"){
  if($model eq "CA"){
   `$EXEC_NAME -i $PDB_DIR/$PDB.pdb -g $PDB.gro -o $PDB.top -n $PDB.ndx -s $PDB.contacts -t $BIFSIF_CA -CG -t_contacts $BIFSIF_AA &> $PDB.output`;
  }elsif($model eq "AA"){
   `$EXEC_NAME -i $PDB_DIR/$PDB.pdb -g $PDB.gro -o $PDB.top -n $PDB.ndx -s $PDB.contacts -t $BIFSIF_AA  &> $PDB.output`;
  }else{
   print "unrecognized model.  Quitting..\n";
   exit;
  }
 }else{
  if($model eq "CA"){
   `$EXEC_NAME -i $PDB_DIR/$PDB.pdb -g $PDB.gro -o $PDB.top -n $PDB.ndx -s $PDB.contacts -t temp.bifsif/ -CG -t_contacts temp.cont.bifsif &> $PDB.output`;
  }elsif($model eq "AA"){
   `$EXEC_NAME -i $PDB_DIR/$PDB.pdb -g $PDB.gro -o $PDB.top -n $PDB.ndx -s $PDB.contacts -t temp.bifsif/  &> $PDB.output`;
  }else{
   print "unrecognized model.  Quitting..\n";
   exit;
  }
 }

 if($model eq "AA"){
  `java -jar $SCM  -g $PDB.gro -t $PDB.top -ch $PDB.ndx -o $PDB.contacts.SCM -m shadow -c $CONTD -s $CONTR -br $BBRAD --distance`;
  my $CONTDIFF=`diff $PDB.contacts $PDB.contacts.SCM | wc -l`;
   if($CONTDIFF > 0){
    print "contact map consistency check: FAILED\n";
    $FAILED++; 
   }else{
    print "contact map consistency check: PASSED\n";
   }
 }elsif($model eq "CA"){
  # run AA model to get top
   `$EXEC_NAME -i $PDB_DIR/$PDB.pdb -g $PDB.meta1.gro -o $PDB.meta1.top -n $PDB.meta1.ndx -s $PDB.meta1.contacts -t $BIFSIF_AA  &> $PDB.meta1.output`;
  `java -jar $SCM   --coarse CA -g $PDB.meta1.gro -t $PDB.meta1.top -ch $PDB.meta1.ndx -o $PDB.contacts.SCM -m shadow -c $CONTD -s $CONTR -br $BBRAD --distance`;
  # run SCM to get map
  my $CONTDIFF=`diff $PDB.contacts $PDB.contacts.SCM | wc -l`;
   if($CONTDIFF > 0){
    print "contact map consistency check: FAILED\n";
    $FAILED++; 
   }else{
    print "contact map consistency check: PASSED\n";
   }
 }

# clean up the tracking for the next test
 foreach my $item(@FAILLIST){
  $FAIL{$item}=1;
 }


 # CHECK THE OUTPUT
 &checkgro; 
 &checkndx;
 &readtop;
 &checkvalues;
 &summary; 

}

sub checkgro
{
 unless(open(GRO,"$PDB.gro")){
  print "ERROR: $PDB.gro can not be opened. This means SMOG died unexpectedly.\n";
  $FAILED++;
  return;
 }
 my $LINE=<GRO>; # header comment
 my $NUMOFATOMS=<GRO>; # header comment
 chomp($NUMOFATOMS);
 # store atom information
 my $XMIN=10000000;
 my $XMAX=-10000000;
 my $YMIN=10000000;
 my $YMAX=-10000000;
 my $ZMIN=10000000;
 my $ZMAX=-10000000;
 $#GRODATA=-1;
 $#XT=-1;
 $#YT=-1;
 $#ZT=-1;
 for(my $I=0;$I<$NUMOFATOMS;$I++){
  $LINE=<GRO>;
  chomp($LINE);
  $LINE =~ s/\s+$//;
  $GRODATA[$I][0]=substr($LINE,0,5);
  $GRODATA[$I][1]=substr($LINE,5,5);
  $GRODATA[$I][2]=substr($LINE,10,5);
  $GRODATA[$I][3]=substr($LINE,15,5);
  $XT[$I+1]=substr($LINE,20,8);
  $YT[$I+1]=substr($LINE,28,8);
  $ZT[$I+1]=substr($LINE,36,8);
  my $X=substr($LINE,20,8);
  my $Y=substr($LINE,28,8);
  my $Z=substr($LINE,36,8);

  if($X > $XMAX){
   $XMAX=$X;
  }
  if($X < $XMIN){
   $XMIN=$X;
  }
  if($Y > $YMAX){
   $YMAX=$Y;
  }
  if($Y < $YMIN){
   $YMIN=$Y;
  }
  if($Z > $ZMAX){
   $ZMAX=$Z;
  }
  if($Z < $ZMIN){
   $ZMIN=$Z;
  }
 }
 $LINE=<GRO>;
 chomp($LINE);
 $LINE =~ /^\s+|\s+$/;
 my @BOUNDS=split(/ /,$LINE);
 $BOUNDS[0]=int(($BOUNDS[0] * $PRECISION))/($PRECISION);
 $BOUNDS[1]=int(($BOUNDS[1] * $PRECISION))/($PRECISION);
 $BOUNDS[2]=int(($BOUNDS[2] * $PRECISION))/($PRECISION);
 my $DX=$XMAX-$XMIN+2;
 my $DY=$YMAX-$YMIN+2;
 my $DZ=$ZMAX-$ZMIN+2;
 $DX=int(($DX * $PRECISION/10.0))/($PRECISION*0.1);
 $DY=int(($DY * $PRECISION/10.0))/($PRECISION*0.1);
 $DZ=int(($DZ * $PRECISION/10.0))/($PRECISION*0.1);
 if(abs($BOUNDS[0]-$DX) > $TOLERANCE || abs($BOUNDS[1] - $DY) > $TOLERANCE || abs($BOUNDS[2] - $DZ) > $TOLERANCE ){
  $FAILED++;
  print "Gro box size inconsistent\n";
  print "$BOUNDS[0], $XMAX, $XMIN,$BOUNDS[1],$YMAX,$YMIN,$BOUNDS[2],$ZMAX,$ZMIN\n";
 }else{
  $FAIL{'BOX'}=0;
  print "Passed gro box size check\n";
 }

}

sub preparesettings
{
 # make a settings file...
 open(READSET,">$PDB.settings") or die  "can not open settings file\n";
 printf READSET ("%s.pdb\n", $PDB);
 printf READSET ("%s.top\n", $PDB);
 if(-e "$PDB.top"){
  `rm $PDB.top`;
 }
 if(-e "$PDB.gro"){
  `rm $PDB.gro`;
 }
 if(-e "$PDB.ndx"){
  `rm $PDB.ndx`;
 }
 printf READSET ("%s.gro\n", $PDB);
 printf READSET ("%s.ndx\n", $PDB);
 printf READSET ("%s\n", "All-Atom");
 # do not upload a contact file.
 printf READSET ("R_CD %s\n", $R_CD);
 printf READSET ("R_P_BB_SC %s\n", $R_P_BB_SC);
 printf READSET ("R_N_SC_BB %s\n", $R_N_SC_BB);
 printf READSET ("PRO_DIH %s\n", $PRO_DIH);
 printf READSET ("NA_DIH %s\n", $NA_DIH);
 printf READSET ("LIGAND_DIH %s\n", $LIGAND_DIH);
 printf READSET ("sigma %s\n", $sigma); 
 printf READSET ("epsilon %s\n", $epsilon);
 printf READSET ("epsilonCAC %s\n", $epsilonCAC);
 printf READSET ("epsilonCAD %s\n", $epsilonCAD);
 printf READSET ("sigmaCA %s\n", $sigmaCA);
 close(READSET);

 if($model eq "CA"){
  $sigmaCA=$sigmaCA/10.0;
  $rep_s12=$sigmaCA**12;
  $sigmaCA=$sigmaCA*10.0;
 }elsif($model eq "AA"){
  $sigma=$sigma/10;
  $rep_s12=$sigma**12*$epsilon;
  $sigma=$sigma*10;
 }else{
  print "unknown model type.  Quitting...\n";
 }

 if(-d "temp.bifsif"){
  `rm -r temp.bifsif`;
 }
  if(-d "temp.cont.bifsif"){
  `rm -r temp.cont.bifsif`;
 }
 if($model eq "CA" && $default ne "yes"){
  `mkdir temp.bifsif temp.cont.bifsif`;
  my $PARM_P_BB=$PRO_DIH;
  my $PARM_P_SC=$PRO_DIH/$R_P_BB_SC;
  my $PARM_N_BB=$NA_DIH;
  my $PARM_N_SC=$NA_DIH*$R_N_SC_BB;
  my $epsilonCAD3=$epsilonCAD/2.0;
  `sed "s/EPS_CONT/$epsilonCAC/g;s/EPS_DIH/$epsilonCAD/g;s/EPS_dih3/$epsilonCAD3/g" $TEMPLATE_DIR_CA/*.sif > temp.bifsif/tmp.sif`;
  `sed "s/PARM_C12/$rep_s12/g;s/EPS_CONT/$epsilonCAC/g" $TEMPLATE_DIR_CA/*.nb > temp.bifsif/tmp.nb`;
  `sed "s/EPS_CONT/$epsilonCAC/g;s/EPS_DIH/$epsilonCAD/g;s/EPS_dih3/$epsilonCAD3/g" $TEMPLATE_DIR_CA/*.b > temp.bifsif/tmp.b`;
  `cp $TEMPLATE_DIR_CA/*.bif temp.bifsif/tmp.bif`;

  `cp $TEMPLATE_DIR_AA_STATIC/*.bif temp.cont.bifsif/tmp.cont.bif`;
  `cp $TEMPLATE_DIR_AA_STATIC/*.nb temp.cont.bifsif/tmp.cont.nb`;
  `cp $TEMPLATE_DIR_AA_STATIC/*.b temp.cont.bifsif/tmp.cont.b`;
  `sed "s/CONTMAP/$CONTTYPE/g;s/CUTDIST/$CONTD/g;s/SCM_R/$CONTR/g" $TEMPLATE_DIR_AA_STATIC/*.sif > temp.cont.bifsif/tmp.cont.sif`;


 } 

 if($model eq "AA" && $default ne "yes"){
  `mkdir temp.bifsif`;
  my $PARM_P_BB=$PRO_DIH;
  my $PARM_P_SC=$PRO_DIH/$R_P_BB_SC;
  my $PARM_N_BB=$NA_DIH;
  my $PARM_N_SC=$NA_DIH*$R_N_SC_BB;
  `sed "s/PARM_C_D/$R_CD/g;s/PARM_P_BB/$PARM_P_BB/g;s/PARM_P_SC/$PARM_P_SC/g;s/PARM_N_BB/$PARM_N_BB/g;s/PARM_N_SC/$PARM_N_SC/g;s/CONTMAP/$CONTTYPE/g;s/CUTDIST/$CONTD/g;s/SCM_R/$CONTR/g" $TEMPLATE_DIR_AA/*.sif > temp.bifsif/tmp.sif`;
  `sed "s/PARM_C12/$rep_s12/g" $TEMPLATE_DIR_AA/*.nb > temp.bifsif/tmp.nb`;
  `cp $TEMPLATE_DIR_AA/*.bif temp.bifsif/tmp.bif`;
  `cp $TEMPLATE_DIR_AA/*.b temp.bifsif/tmp.b`;
 }
}


sub checkndx
{

 `bin/top.clean.bash $PDB.ndx $PDB.ndx2`;
 `mv $PDB.ndx2 $PDB.ndx`;
 open(NDX,"$PDB.ndx") or die "no ndx file\n"; 
 while(<NDX>){
  my $LINE=$_;        
  chomp($LINE);
  $LINE =~ s/\s+$//;
  my @A=split(/ /,$LINE);
  my $CHAIN;
  if($A[0] eq "["){
   $CHAIN=$A[1];
  }else{
   $CID[$LINE]=$CHAIN;
  }
 }

}

sub readtop
{

 my %FOUND;
 `bin/top.clean.bash $PDB.top $PDB.top2`;
 `mv $PDB.top2 $PDB.top`;
 $DIH_MIN=100000000;
 $DIH_MAX=-100000000;
 $NCONTACTS=0;
 open(TOP,"$PDB.top") or die " $PDB.top can not be opened...\n";
 $NUCLEIC_PRESENT=0;
 $AMINO_PRESENT=0;
 $LIGAND_PRESENT=0;
 $ION_PRESENT=0;
 my @theta_gen;
 my @PAIRS;
 my %dihedral_array1;
 my %dihedral_array2;
 my %dihedral_array3;
 @FIELDS=("defaults","atomtypes","moleculetype","atoms","pairs","bonds","angles","dihedrals","system","molecules","exclusions");
 foreach(@FIELDS){
  $FOUND{$_}=0;
 }

 my %theta_gen_as;
 my %phi_gen_as;
 my @phi_gen;
 my %improper_gen_as;
 my @improper_gen;
 my @A;
 while(<TOP>){
  my $LINE=$_;
  chomp($LINE);
  $LINE =~ s/\s+$//;
  @A=split(/ /,$LINE);
  if(exists $A[1]){
   if($A[1] eq "defaults"){
    $FOUND{'defaults'}=1;
    $LINE=<TOP>;
    chomp($LINE);
    $LINE =~ s/\s+$//;
    @A=split(/ /,$LINE);
    if($A[0] != 1){
     print "default nbfunc is not correctly set.\n";
     $FAILED++;
    }
    if($A[1] != 1){
     print "default comb-rule is not correctly set.\n";
     $FAILED++;
    }
    if($A[2] ne "no"){
     print "default gen-pairs is not correctly set.\n";
     $FAILED++;
    }
   }
  }
  if(exists $A[1]){
   if($A[1] eq "atomtypes"){
    $FOUND{'atomtypes'}=1;
    $#A = -1;
    $LINE=<TOP>;
    $LINE =~ s/\s+$//;
    @A=split(/ /,$LINE);
    my $numtypes=0;
    my $mass1=0;
    my $charge1=0;
    my $particle1=0;
    my $c61=0;
    my $excl1=0;
    until($A[0] eq "["){
     $numtypes++;
     if($A[1] == 1){
      $mass1++;
     }
     if($A[2] == 0){
      $charge1++;
     }
     if($A[3] eq "A"){
      $particle1++;
     }
     if($A[4] == 0.0){
      $c61++
     }
     if($A[5] > $MINTHR*$rep_s12 && $A[5] < $MAXTHR*$rep_s12){
      $excl1++;
     }
     $#A = -1;
     $LINE=<TOP>;
     $LINE =~ s/\s+$//;
     last unless defined $LINE;
     @A=split(/ /,$LINE);
    }
    if($numtypes == $mass1 and $mass1 !=0){
      $FAIL{'MASS'}=0;
    }
    if($numtypes == $charge1 and $charge1 !=0){
      $FAIL{'CHARGE'}=0;
    }
    if($numtypes == $particle1 and $particle1 !=0){
      $FAIL{'PARTICLE'}=0;
    }
    if($numtypes == $c61 and $c61 !=0){
      $FAIL{'C6 VALUES'}=0;
    }
    if($numtypes == $excl1 and $excl1 !=0){
      $FAIL{'C12 VALUES'}=0;
    }



   }
  } 
  if(exists $A[1]){
   # check the excluded volume is consistent with the settings.
   if($A[1] eq "moleculetype"){
    $FOUND{'moleculetype'}=1;
    my $LINE=<TOP>;
    chomp($LINE); 
    $LINE =~ s/\s+$//;
    @A=split(/ /,$LINE);
    if($A[0] ne "Macromolecule"){
     print "default molecule name is off.\n";
     $FAILED++;
    }
    if($A[1] != 3){
     print "nrexcl is not set to 3.\n";
     $FAILED++;
    }
   }
  } 
  if(exists $A[1]){
   # read the atoms, and store information about them
    my $FAIL_GROTOP=0;
   if($A[1] eq "atoms"){
    $FOUND{'atoms'}=1;
    $NUMATOMS=0;
    $NUMATOMS_LIGAND=0;
    $#A = -1;
    $LINE=<TOP>;
    $LINE =~ s/\s+$//;
    @A=split(/ /,$LINE);
    until($A[0] eq "["){
    # store information about each atom
    # atom name
     $ATOMNAME[$A[0]]=$A[4];
     for(my $J=0;$J<5;$J++){
      $A[$J] =~ s/^\s+|\s+$//g;
     }
     for(my $J=0;$J<4;$J++){
      $GRODATA[$NUMATOMS][$J] =~ s/^\s+|\s+$//g;
     }
     if($A[0] != $GRODATA[$NUMATOMS][3]){
      $FAIL_GROTOP++;
     }

    if($A[4] ne $GRODATA[$NUMATOMS][2]){
      $FAIL_GROTOP++;
    }
     # check if it is a backbone atom. This list does not include CA and C1* because this classification is only used for determining which bonds are backbone and which are sidechain
     if(exists $BBTYPE{$A[4]}){
      $ATOMTYPE[$A[0]]=$BBTYPE{$A[4]};
     }else{
      $ATOMTYPE[$A[0]]="NOTBB";
     }
     # residue number
     $RESNUM[$A[0]]=$A[2];
     if($A[2] != $GRODATA[$NUMATOMS][0]){
      $FAIL_GROTOP++;
     }
     # residue name
     if($A[3] ne $GRODATA[$NUMATOMS][1]){
      $FAIL_GROTOP++;
     }
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
     $LINE =~ s/\s+$//;
     last unless defined $LINE;
     @A=split(/ /,$LINE);
    }
   if($FAIL_GROTOP ==0){
    $FAIL{'GRO-TOP CONSISTENCY'}=0;
   }
   }
  } 
  if(exists $A[1]){  
   # read the bonds.  Make sure they are not assigned twice.  Also, save the bonds, so we can generate all possible bond angles later.
   if($A[1] eq "bonds"){
    $FOUND{'bonds'}=1;
    $#A = -1;
    my @bonds;
    $#bonds = -1;
    my @bondWatom;
    $#bondWatom = -1;
    my @NbondWatom;
    $#NbondWatom = -1;
    my $doublebond=0;
    $bondtype6=0;
    my $Nbonds=0;
    my %bond_array;
    undef %bond_array;
    my $string;
    my $NBONDS=0;
    my $RECOGNIZEDBTYPES=0;
    my $CORRECTBONDWEIGHTS=0;
    for (my $I=1;$I<=$NUMATOMS;$I++){
       $NbondWatom[$I]=0;
    }
    $LINE=<TOP>;
    $LINE =~ s/\s+$//;
    @A=split(/ /,$LINE);
    until($A[0] eq "["){
     $NBONDS++;
     if($A[2] == 1){
      $RECOGNIZEDBTYPES++;
      if($A[4] != $bondEps){
       print "bond has incorrect weight\n";
       print "$LINE";
      }else{
       $CORRECTBONDWEIGHTS++;
      }		
      if($A[0] < $A[1]){
       $string=sprintf("%i-%i", $A[0], $A[1]);
      }else{
       $string=sprintf("%i-%i", $A[1], $A[0]);
      }
      ##check if bond has already appeared in the .top file
      if(!exists $bond_array{$string}){
       ## bond was not assigned.
       $bond_array{$string}=1;
       $bonds[$Nbonds][0]=$A[0];
       $bonds[$Nbonds][1]=$A[1];
       # this organization is strange, but it will make sense later...
       $bondWatom[$A[0]][$NbondWatom[$A[0]]]= $Nbonds;
       $bondWatom[$A[1]][$NbondWatom[$A[1]]]= $Nbonds;
       $NbondWatom[$A[0]]++;
       $NbondWatom[$A[1]]++;
       $Nbonds++;
      }else{
      ## bond has already been assigned.
       $doublebond++;
      }
     }elsif($A[2] ==6){
      $RECOGNIZEDBTYPES++;
      $bondtype6++;
       if($A[4] != $bondMG){
        print "BMG bond has incorrect weight\n";
        print "$LINE";
       }else{
       $CORRECTBONDWEIGHTS++;
      }		
     }else{
       print "unknown function type for bond\n";
       print "$LINE";
     }
     $LINE=<TOP>;
     last unless defined $LINE;
     $LINE =~ s/\s+$//;
     @A=split(/ /,$LINE);
    }

    if($doublebond ==0){
     $FAIL{'DUPLICATE BONDS'}=0;
    }

    if($RECOGNIZEDBTYPES == $NBONDS && $NBONDS !=0){
     $FAIL{'SUPPORTED BOND TYPES'}=0;
    }
    if($CORRECTBONDWEIGHTS == $NBONDS && $NBONDS !=0){
     $FAIL{'BOND STRENGTHS'}=0;
    }
 
    # generate the angles
    # generate all possible bond angles based on bonds
    undef %theta_gen_as;
    $theta_gen_N=0;
    $#theta_gen=-1;
    for(my $i=1;$i<=$NUMATOMS;$i++){
    # go through the atoms.  For each atom, check all of the bonds it is involved in, and see if we can make a bond angle out of it.
     for(my $j=0;$j<$NbondWatom[$i];$j++){
      for(my $k=$j+1;$k<$NbondWatom[$i];$k++){
       if($j!=$k){
        my $A1=$bonds[$bondWatom[$i][$j]][0];
        my $A2=$bonds[$bondWatom[$i][$j]][1];
        my $B1=$bonds[$bondWatom[$i][$k]][0];
        my $B2=$bonds[$bondWatom[$i][$k]][1];
        my ($theta1,$theta2,$theta3);
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
        $theta_gen_N++;
       }
      }
     }
    }
   }
  } 
  if(exists $A[1]){ 
   if($A[1] eq "angles"){
    $FOUND{'angles'}=1;
    $#A = -1;
    my $doubleangle=0;
    my $Nangles=0;
    my (@angles1,@angles2); 
    $#angles1 =-1;
    my @angleWatom;
    my @NangleWatom;
    $#angleWatom = -1;
    $#NangleWatom = -1;
    $Nangles=0;
    my $CORRECTAT=0;
    my $CORRECTAW=0;
    for (my $I=1;$I<=$NUMATOMS;$I++){
       $NangleWatom[$I]=0;
    }

    my %angle_array;
    my $string;
    $LINE=<TOP>;
    $LINE =~ s/\s+$//;
    @A=split(/ /,$LINE);
    until($A[0] eq "["){
     if($A[3] == 1){
      $CORRECTAT++;
     }
     if($A[5] == $angleEps){
      $CORRECTAW++;
     }
     if($A[0] < $A[2]){
      $string=sprintf("%i-%i-%i", $A[0], $A[1], $A[2]);
     }else{
      $string=sprintf("%i-%i-%i", $A[2], $A[1], $A[0]);
     }
     # save the angles
     $angles1[$Nangles]="$string";
     #check if bond has been seen already...
     if(!exists $angle_array{$string} ){
      ## bond was not assigned.
      $angle_array{$string}=1;
      $angles2[$Nangles][0]=$A[0];
      $angles2[$Nangles][1]=$A[1];
      $angles2[$Nangles][2]=$A[2];
      # this organization is also strange, but it will make sense later...
      $angleWatom[$A[0]][$NangleWatom[$A[0]]]= $Nangles;
      $angleWatom[$A[1]][$NangleWatom[$A[1]]]= $Nangles;
      $angleWatom[$A[2]][$NangleWatom[$A[2]]]= $Nangles;
      $NangleWatom[$A[0]]++;
      $NangleWatom[$A[1]]++;
      $NangleWatom[$A[2]]++;
      $Nangles++;
     }else{
      ## bond has already been assigned.
      $doubleangle++;
     }
     $LINE=<TOP>;
     last unless defined $LINE;
     $LINE =~ s/\s+$//;
     @A=split(/ /,$LINE);
    }
    if($doubleangle ==0){
     $FAIL{'DUPLICATE ANGLES'}=0;
    } 
    if($Nangles == $CORRECTAT && $Nangles > 0){
     $FAIL{'ANGLE TYPES'}=0;
    }
    if($Nangles == $CORRECTAW && $Nangles > 0){
     $FAIL{'ANGLE WEIGHTS'}=0;
    }

    ## cross-check the angles
    if($theta_gen_N == $Nangles){
     $FAIL{'ANGLE CONSISTENCY'}=0;
    }else{
     print "the number of generated angles is inconsistent with the number of angles in the top file\n";
     print "$theta_gen_N $Nangles\n";
     $FAIL{'ANGLE CONSISTENCY'}=1;
    }
    my $CONangles=0;
    # check to see if all the generated angles (from this script) are present in the top file
    for(my $i=0;$i<$theta_gen_N;$i++){
     if(exists $angle_array{$theta_gen[$i]} ){
       $CONangles++;
      }else{
       print "angle generated, but not in top: $theta_gen[$i]\n";
     }
    }
    if($CONangles == $theta_gen_N){
     $FAIL{'ANGLE CONSISTENCY'}=0;
    }else{
     $FAIL{'ANGLE CONSISTENCY'}=0;
    }

    $CONangles=0;
    # check to see if all top angles are present in the generate list.
    for(my $i=0;$i<$Nangles;$i++){
     if(exists $theta_gen_as{$angles1[$i]}){
      $CONangles++;
     }else{
      print "angle in top, but not generated: $angles1[$i]\n";
     }
    }
     if($CONangles == $Nangles){
     $FAIL{'ANGLE CONSISTENCY'}=0;
    }else{
     $FAIL{'ANGLE CONSISTENCY'}=0;
    }

 
    # generate all possible dihedral angles based on bond angles
    undef %phi_gen_as;
    $phi_gen_N=0;
    $#phi_gen=-1;
    undef %improper_gen_as;
    $improper_gen_N=0;
    $#improper_gen=-1;
    for(my $i=1;$i<=$NUMATOMS;$i++){
    # go through the atoms.  For each atom, check all of the angles it is involved in, and see if we can make a angle angle out of it.
     for(my $j=0;$j<$NangleWatom[$i];$j++){
      for(my $k=$j+1;$k<$NangleWatom[$i];$k++){
       if($j!=$k){
        my $A1=$angles2[$angleWatom[$i][$j]][0];
        my $A2=$angles2[$angleWatom[$i][$j]][1];
        my $A3=$angles2[$angleWatom[$i][$j]][2];
        my $B1=$angles2[$angleWatom[$i][$k]][0];
        my $B2=$angles2[$angleWatom[$i][$k]][1];
        my $B3=$angles2[$angleWatom[$i][$k]][2];
        my ($phi1,$phi2,$phi3,$phi4);
        # find all the dihedral angles that can be made with these angles
        my $formed='not';
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
         $phi_gen_N++;
        }elsif($formed eq "improper"){
         my @phit;
        	$phit[0]=$phi1;
        	$phit[1]=$phi2;
        	$phit[2]=$phi3;
        	$phit[3]=$phi4;
        	for(my $ii=0;$ii<4;$ii++){
          $phi1=$phit[$ii];
        	 for(my $jj=0;$jj<4;$jj++){
        	  if($ii != $jj){
        	   $phi2=$phit[$jj];
            for(my$kk=0;$kk<4;$kk++){
             if($kk != $jj && $kk != $ii){
              $phi3=$phit[$kk];
              for(my $ll=0;$ll<4;$ll++){
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
  } 
  if(exists $A[1]){
   if($A[1] eq "dihedrals"){
    my $CORIMP=0;
    $FOUND{'dihedrals'}=1;
    if($model ne "CA" ){
     $FAIL{'CA DIHEDRAL WEIGHTS'}=-1;
    }
    $DENERGY=0;
    my $doubledih1=0;
    my $doubledih2=0;
    my $doubledih3=0;
    my $Nphi=0;
    my $solitary3=0;
    $FAIL_W3=0;
    $FAIL_S3=0;
    $FAIL_A3=0;
    my $string;
    my @phi;
    my $LAST_W;
    my $string_last;
    my $DANGLE_LAST;
    my $LAST_N=0;
    my $DIHSW=0;
    my $accounted=0;
    my $accounted1=0;
    $#A = -1;
    $#ED_T = -1;
    $#EDrig_T = -1;
    $LINE=<TOP>;
    $LINE =~ s/\s+$//;
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

    # #check if dihedral has been seen already...

       # check duplicate type 3 
       if(!exists $dihedral_array3{$string} and exists $A[7] and $A[7] == 3){
        $dihedral_array3{$string}=1;
        $accounted++;
	if(!exists $dihedral_array3{$string}){
         $solitary3++;
         print "Type 3 dihedral appeared w/o a type 1...\n  $LINE\n";
        }
       }elsif(exists $dihedral_array3{$string} and exists $A[7] and $A[7] == 3){
        $doubledih3++; 
        print "Duplicate dihedral\n   $LINE\n";
       }elsif(!exists $dihedral_array1{$string} and exists $A[7] and $A[7] == 1){
	#check duplicate type 1 and 2
        ## dihedral was not assigned.
        $dihedral_array1{$string}=1;
        $accounted++;
        $accounted1++;
       }elsif(exists $dihedral_array1{$string} and exists $A[7] and $A[7] == 1){
        $doubledih1++;
        print "Duplicate dihedral\n   $LINE\n";
       }elsif(!exists $dihedral_array2{$string} and $A[4] == 2){
        $dihedral_array2{$string}=1;
        $accounted++;
       }elsif(exists $dihedral_array2{$string} and $A[4] == 2){
        $doubledih2++;
        print "Duplicate dihedral\n   $LINE\n";
       }else{
        internal_error('DUPLICATE DIHEDRAL CHECKING')
       }

     ##if dihedral is type 1, then save the information, so we can make sure the next is n=3
     if(exists $A[7]){
      if($A[7] == 1){
       $LAST_W=$A[6];
       $string_last=$string;
       $DANGLE_LAST=$A[5];
      }
#      if($LAST_N == 1 && $A[7] != 3){
#       $FAIL_check13++;
#       print "1-3 pairs not consistent.  Offending line:\n";
#       print "$LINE\n";
#      }
      $LAST_N=$A[7];
      if($A[7] == 3 && ($A[6] < $MINTHR*0.5*$LAST_W || $A[6] > $MAXTHR*0.5*$LAST_W)){
       $FAIL_W3++; 
      }
      if($A[7] == 3 && ($string ne $string_last)){
       $FAIL_S3++; 
      }
      if($A[7] == 3 && ( ($A[5] % 360) < $MINTHR*(3*$DANGLE_LAST % 360) || ($A[5] % 360) > $MAXTHR*(3*$DANGLE_LAST % 360)  )){
       $FAIL_A3++; 
      }
      if($A[4] == 1 && $A[7] == 1 ){
       my $F;
       if(($A[6] > $MINTHR*$epsilonCAD && $A[6] < $MAXTHR*$epsilonCAD) && $model eq "CA"){
        $DIHSW++;
       }elsif(($A[6] < $MINTHR*$epsilonCAD || $A[6] > $MAXTHR*$epsilonCAD) && $model eq "CA"){
        print "error in dihedral strength on line:";
        print "$LINE\n";
       }
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
     }
     if($A[4] == 2 && !exists $improper_gen_as{$string}){
      my $F;
      if($A[1] > $A[2]){
       $F=$A[1]-$A[2];
       if(!exists $EDrig_T[$A[2]][$F]){
        $EDrig_T[$A[2]][$F]=$A[6];
       }else{
        $EDrig_T[$A[2]][$F]+=$A[6];
       }
      }else{
       $F=$A[2]-$A[1];
       if(!exists $EDrig_T[$A[1]][$F]){
	$EDrig_T[$A[1]][$F]=$A[6];
       }else{
        $EDrig_T[$A[1]][$F]+=$A[6];
       }
      }
     
      if($F > $DISP_MAX){
       $DISP_MAX=$F;
      }
     }
     if($A[4] == 2 && exists $improper_gen_as{$string} ){
       $CORIMP++;
      if($impEps == $A[6]){
       $CORIMP--;
      }else{
       print "improper dihedral has wrong weight\n";
       print "$LINE";
      }
     }

     $#A = -1;
     $LINE=<TOP>;
     last unless defined $LINE;
     $LINE =~ s/\s+$//;
     @A=split(/ /,$LINE);
    }


    # All dihedrals read in.  Now do checking

    $FAIL_phi=0;
    # check to see if all the generated dihedrals (from this script) are present in the top file
    for(my $i=0;$i<$phi_gen_N;$i++){
     if(!exists $dihedral_array1{$phi_gen[$i]} and !exists $dihedral_array2{$phi_gen[$i]} ){
      $FAIL_phi++;
      print "Generated dihedral $phi_gen[$i] is not in the list of included dihedrals...\n";
#      print "$FAIL_phi $i $phi_gen[$i] $dihedral_array{$phi_gen[$i]}\n";
     }
    }
    # check to see if all top dihedrals are present in the generate list.
    for(my $i=0;$i<$Nphi;$i++){
     if(!exists $phi_gen_as{$phi[$i]}  && !exists $improper_gen_as{$phi[$i]} ){
      $FAIL_phi++;
      print "An included dihedral can not be found in the list of generated ones...";
      print "$FAIL_phi, $i, $phi[$i], $phi_gen_as{$phi[$i]}\n"
     }
    }
    if($CORIMP == 0){
     $FAIL{'IMPROPER WEIGHTS'}=0;
    } 
    if($model eq "CA" && $Nphi/2 == $DIHSW){
     $FAIL{'CA DIHEDRAL WEIGHTS'}=0;
    }else{
     print "$Nphi $DIHSW\n";
    }

    if($Nphi == $accounted and $Nphi != 0){
     $FAIL{'CLASSIFYING DIHEDRALS'}=0;
    }else{
     print "$Nphi $DIHSW\n";
    }
    if($doubledih1 == 0){
     $FAIL{'DUPLICATE TYPE 1 DIHEDRALS'}=0;
    }
    if($doubledih2 == 0){
     $FAIL{'DUPLICATE TYPE 2 DIHEDRALS'}=0;
    }
    if($doubledih3 == 0){
     $FAIL{'DUPLICATE TYPE 3 DIHEDRALS'}=0;
    }
    if($solitary3 == 0){
     $FAIL{'3-1 DIHEDRAL PAIRS'}=0;
    }
    my $matchingpairs=0;
    foreach my $pair (keys %dihedral_array1){
     if(exists $dihedral_array3{$pair}){
      $matchingpairs++;
     }
    }
    if($matchingpairs == $accounted1){
     $FAIL{'1-3 DIHEDRAL PAIRS'}=0
    }

   }
  } 
  
  if(exists $A[1]){
   # check values for contact energy
   if($A[1] eq "pairs"){
    $FOUND{'pairs'}=1;
   # reset all the values because we can analyze multiple settings, and we want to make sure we always start at 0 and with arrays cleared.
    $stackingE=0;
    $NonstackingE=0;
    $CONTENERGY=0;
    $FAIL_STACK=0;
    $FAIL_NONSTACK=0;
    $FAIL_LONGCONT=0;
    $FAIL_CONTACT=0;
    $FAIL_ContactDist=0;
    $#A = -1;
    $LINE=<TOP>;
    $LINE =~ s/\s+$//;
    @A=split(/ /,$LINE);
    my $W;
    my $Cdist;
    my $CALCD;
    until($A[0] eq "["){
     $PAIRS[$NCONTACTS][0]=$A[0];
     $PAIRS[$NCONTACTS][1]=$A[1];
     $NCONTACTS++;
     # determine the epsilon of the contact
     if($A[4] == 0){
      print "\nERROR: A divide by zero was encountered during testing. This typically means the top file is incomplete\n";
      $FAILED++; 
      last;
     }
     if($model eq "CA"){
      $W=5.0**5.0/6.0**6.0*($A[3]**6.0)/($A[4]**5.0);
     }elsif($model eq "AA"){
      $W=($A[3]*$A[3])/(4*$A[4]);
     }else{
      print "unrecognized model.  Quitting...\n";
      exit;
     }
     if($model eq "AA"){
      $Cdist=(2*$A[4]/($A[3]))**(1.0/6.0);
      $CALCD=(($XT[$A[0]]-$XT[$A[1]])**2+($YT[$A[0]]-$YT[$A[1]])**2+($ZT[$A[0]]-$ZT[$A[1]])**2)**(0.5);
      if(abs($Cdist-$CALCD) > 10.0/($PRECISION*1.0) ){
       $FAIL_ContactDist++;
      }
     }elsif($model eq "CA"){
      $Cdist=(6.0*$A[4]/(5.0*$A[3]))**(1.0/2.0);
      $CALCD=(($XT[$A[0]]-$XT[$A[1]])**2+($YT[$A[0]]-$YT[$A[1]])**2+($ZT[$A[0]]-$ZT[$A[1]])**2)**(0.5);
      if(abs($Cdist-$CALCD) > 10.0/($PRECISION*1.0)){
       $FAIL_ContactDist++;
      }
     }
     # so long as the contacts are not with ligands, then we add the sum
     if($model eq "CA"){
      $CONTENERGY+=$W;
      if($W < $MINTHR*$epsilonCAC || $W > $MAXTHR*$epsilonCAC){
       $FAIL_CONTACT++;
       print "Error in EpsilonC values\n";
       print "Value: Target\n";
       print "$W $epsilonCAC\n";
       print "line:\n";
       print "$LINE\n";
      }
     }elsif($model eq "AA"){
      if(int(($Cdist * $PRECISION))/($PRECISION*1.0) > $CONTD/10.0){
       print "long contacts! distance $Cdist nm.\n";
       print "$LINE";
       $FAIL_LONGCONT++;
      }
      ## so long as the contacts are not with ligands, then we add the sum
      if($MOLTYPE[$A[0]] ne "LIGAND" and $MOLTYPE[$A[1]] ne "LIGAND"){
       $CONTENERGY+=($A[3]*$A[3])/(4*$A[4]);
      }
      if($MOLTYPE[$A[0]] eq "NUCLEIC" and $MOLTYPE[$A[1]] eq "NUCLEIC" and $ATOMTYPE[$A[0]] ne "BACKBONE" and  $ATOMTYPE[$A[1]] ne "BACKBONE" and $ATOMNAME[$A[0]] ne "C1\*" and $ATOMNAME[$A[1]] ne "C1\*" and abs($RESNUM[$A[0]]-$RESNUM[$A[1]]) == 1 and $CID[$A[0]] == $CID[$A[1]]){
       # if we haven't assigned a value to stacking interactions, then let's save it
       # if we have saved it, check to see that this value is the same as the previous ones.
       if($stackingE == 0 ){
        $stackingE=$W;
       }elsif(abs($stackingE - $W) > 10.0/($PRECISION*1.0) ){
        $FAIL_STACK++;
        print "error in stacking energies: $stackingE  $W $A[0] $A[1] \n";
        }
      }else{
      # it is not a stacking contact.  Do the same checks for non-stacking interactions
       if($NonstackingE == 0 ){
        $NonstackingE=$W;
       }elsif(abs($NonstackingE - $W) > 10.0/($PRECISION*1.0) ){
        $FAIL_NONSTACK++;
        print "error in non-stacking contacts: $NonstackingE $W\n";
        print "line:\n";
        print "$LINE\n";
       }
      }
     }else{
      print "unrecognized model.  Quitting...\n";
      die;
     }
     # truncate the epsilon, for comparison purpsoses later.
     $W=int(($W * $PRECISION))/($PRECISION*1.0);
     # check to see if the contact is nucleic acids, adjacent residues and not backbone atoms.  These should be rescaled by a factor of 1/3
     # read the next line
     $#A = -1;
     $LINE=<TOP>;
     last unless defined $LINE;
     $LINE =~ s/\s+$//;
     @A=split(/ /,$LINE);
    }
   }
  } 
  if(exists $A[1]){ 
   if($A[1] eq "exclusions"){
    $FOUND{'exclusions'}=1;
    $#A = -1;
    $LINE=<TOP>;
    $LINE =~ s/\s+$//;
    @A=split(/ /,$LINE);
    my $NEXCL=0;
    $FAIL_EXCLUSIONS=0;
    until($A[0] eq "["){
     if($PAIRS[$NEXCL][0] != $A[0] || $PAIRS[$NEXCL][1] != $A[1]){
      $FAIL_EXCLUSIONS++;
      print "FAIL: mis-match between pairs and exclusions (pair $NEXCL)\n";
      print "pair: $PAIRS[$NEXCL][0] $PAIRS[$NEXCL][1]\n";
      print "excl: $A[0] $A[1]\n";
     }
     $NEXCL++;
     # read the next line
     $#A = -1;
     $LINE=<TOP>;
     last unless defined $LINE;
     $LINE =~ s/\s+$//;
     @A=split(/ /,$LINE);
    }
    print "checking number of contacts and exclusions match...\n";
    if($NEXCL == $NCONTACTS){
     print "$NEXCL $NCONTACTS PASSED\n";
    }else{
     print "FAILED\n";
     $FAIL_EXCLUSIONS++;
    }
   }
  }
  if(exists $A[1]){
   if($A[1] eq "system"){
    $FOUND{'system'}=1;
    $LINE=<TOP>;
    chomp($LINE);
    $LINE =~ s/\s+$//;
    @A=split(/ /,$LINE);
    if($A[0] ne "Macromolecule"){
     print "default system name is off\n";
     $FAILED++;
    }
   }
  }
  if(exists $A[1]){
   if($A[1] eq "molecules"){
    $FOUND{'molecules'}=1;
    $LINE=<TOP>;
    chomp($LINE);
    $LINE =~ s/\s+$//;
    @A=split(/ /,$LINE);
    if($A[0] ne "Macromolecule"){
     print "default system name is off\n";
     $FAILED++;
    }
     if($A[1] != 1){
     print "wrong number of molecules...\n";
     $FAILED++;
    }
   }
  }
 }


 foreach(@FIELDS){
  my $FF=$_;
  if($FOUND{"$FF"} == 1){
   print "Found: [ $FF ] in top file.\n";
  }elsif($FOUND{"$FF"} == 0){
   print "Error: [ $FF ] not found in top file.  This either means SMOG did not complete, or there was a problem reading the file.  All subsequent output will be meaninglyess.\n";
   $FAILED++;
  }else{
   print "ERROR: Problem understanding .top file...\n";
   $FAILED++;
  };
 }
}


sub checkvalues
{

 ## DONE READING IN THE FILE.  TIME TO CHECK AND SEE IF ALL THE RATIOS ARE CORRECT
 print "number of atoms = $NUMATOMS\n";
 print "number of atoms(excluding ligands) = $NUMATOMS_LIGAND\n";
 print "Dihedral energy = $DENERGY\n";
 print "Contact energy = $CONTENERGY\n";
 print "max dihedral = $DIH_MAX\n";
 print "min dihedral = $DIH_MIN\n";
 print "generated angles, dihedrals, impropers\n";
 print "$theta_gen_N $phi_gen_N $improper_gen_N\n";
 if($model eq "CA"){
  if($theta_gen_N == 0 || $phi_gen_N == 0 ){
   print "couldnt generate something....\n";
   $FAILED++;
  }
 }elsif($model eq "AA"){
  if($theta_gen_N == 0 || $phi_gen_N == 0 ||  $improper_gen_N == 0){
   print "couldnt generate something....\n";
   $FAILED++;
  }
 }else{
  print "unrecognized model. Quitting...\n";
  die;
 }
 ## check the energy per dihedral and where the dihedral is SC/BB NA/AMINO
 if($DISP_MAX == 0){
  print "internal error: Quitting.  Please report to info\@smog-server.org\n";
 }
 my $PBBfail=0;
 my $PSCfail=0;
 my $NABBfail=0;
 my $NASCfail=0;
 my $PBBvalue=0;	
 my $PSCvalue=0;	
 my $NABBvalue=0;	
 my $NASCvalue=0;
 my $rigid_fail=0;
 my $NUM_NONZERO=0;
 my $LIGdfail=0;
 my $LIGdvalue=0;
 for(my $i=0;$i<$NUMATOMS+1;$i++){
  for(my $j=0;$j<=$DISP_MAX;$j++){
   if(exists $EDrig_T[$i][$j]){
    $NUM_NONZERO++;	
    if( ($ATOMNAME[$i] eq "C"  && $ATOMNAME[$i+$j] eq "N") || (  $ATOMNAME[$i] eq "N"  && $ATOMNAME[$i+$j] eq "C"   )){
     if( abs($EDrig_T[$i][$j]-$omegaEps) > $TOLERANCE ){
      print "weird omega rigid...\n";
      print "$i $j $EDrig_T[$i][$j]\n";
      print "$ATOMNAME[$i] $ATOMNAME[$i+$j]\n"; 
      print "$RESNUM[$i] $RESNUM[$i+$j]\n\n";
      $rigid_fail++;	
     }
    }else{
     if(abs($EDrig_T[$i][$j]-$ringEps) > $TOLERANCE ){
      print "weird ring dihedral...\n";
      print "$i $j $EDrig_T[$i][$j]\n";
      print "$ATOMNAME[$i] $ATOMNAME[$i+$j]\n";
      print "$RESNUM[$i] $RESNUM[$i+$j]\n\n";
      $rigid_fail++;
     }
    }
   }
 
   if(exists $ED_T[$i][$j]){
    $ED_T[$i][$j]= int(($ED_T[$i][$j] * $PRECISION))/($PRECISION*1.0) ;
    if($MOLTYPE[$i] eq "AMINO"){
     if($ATOMTYPE[$i] eq "BACKBONE" or  $ATOMTYPE[$i+$j] eq "BACKBONE"){
#      $DIH_TYPE[$i][$j]="AMINOBB";
      if($PBBvalue !=$ED_T[$i][$j] && $PBBvalue !=0){
       print "FAILED: protein backbone dihedral $i $j failed\n";
       print "$PBBvalue is before\n";
       print "$ED_T[$i][$j] is the bad one...\n";
       $PBBfail++;
      }
      $PBBvalue=$ED_T[$i][$j];
     }else{
#      $DIH_TYPE[$i][$j]="AMINOSC";
      if($PSCvalue !=$ED_T[$i][$j] && $PSCvalue !=0){
       $PSCfail++;
       print "$PSCvalue is before\n";
       print "$ED_T[$i][$j] is the bad one...\n";
      }
     $PSCvalue=$ED_T[$i][$j];
     }
    }elsif($MOLTYPE[$i] eq "NUCLEIC"){
     if($ATOMTYPE[$i] eq "BACKBONE" or  $ATOMTYPE[$i+$j] eq "BACKBONE"){
#      $DIH_TYPE[$i][$j]="NUCLEICBB";
      if($NABBvalue !=$ED_T[$i][$j] && $NABBvalue != 0 ){
       $NABBfail++;
       print "$NABBvalue is before\n";
       print "$ED_T[$i][$j] is the bad one...\n";
      }
      $NABBvalue=$ED_T[$i][$j];
     }else{
#      $DIH_TYPE[$i][$j]="NUCLEICSC";
      if($NASCvalue !=$ED_T[$i][$j] && $NASCvalue !=0){
       $NASCfail++;
       print "$NASCvalue is before\n";
       print "$ED_T[$i][$j] is the bad one...\n";
      }
      $NASCvalue=$ED_T[$i][$j];
     }
    }elsif($MOLTYPE[$i] eq "LIGAND"){
#     $DIH_TYPE[$i][$j]="LIGAND";
     if($LIGdvalue !=$ED_T[$i][$j] && $LIGdvalue != 0 ){
      $LIGdfail++;
      print "backbone atom $i $j failed\n";
      print "$LIGdvalue is before\n";
      print "$ED_T[$i][$j] is the bad one...\n";
     }
     $LIGdvalue=$ED_T[$i][$j];
    }
   }
  }
 }


 foreach my $TEST (@FAILLIST){
  if($FAIL{$TEST}==1){
   print "$TEST CHECK : FAILED\n";
   $FAILED++;
  }elsif($FAIL{$TEST}==0){
   print "$TEST CHECK : PASSED\n";
  }elsif($FAIL{$TEST}==-1){
   print "$TEST CHECK : N/A here\n";
  }else{
   internal_error("$TEST");
  }
 }
 

 if($FAIL_CONTACT>0){
  print "FAIL: some contacts were not the proper strength\n";
  $FAILED++;
 }else{
  print "contact strength: PASSED\n";
 }
 if($FAIL_ContactDist>0){
  print "Contact distance consistency: FAILED\n";
  $FAILED++;
 }else{
  print "Contact distance consistency: PASSED\n";
 }
 if($FAIL_phi >0){
  print "Something funny with the dihedral angles... not consistent between script and top.\n";
  $FAILED++;
 }else{
  print "dihedral angles: PASSED\n";
 }
 if($rigid_fail >0){
  print "Rigid dihedrals do not have the correct strengths\n";
  $FAILED++;
 }else{
  print "strength of rigid dihedrals: PASSED\n";
 }
 if($FAIL_W3 > 0){
  print "energies of n=1 and n=3 dihedrals are not consistent: FAILED\n";
  $FAILED++;
 }else{
  print "energies of n=1 and n=3 dihedrals: PASSED\n";
 }
 if($FAIL_S3 > 0){
  print "ordering of n=1 and n=3 dihedrals is not consistent: FAILED\n";
  $FAILED++;
 }else{
  print "ordering of n=1 and n=3 dihedrals: PASSED\n";
 }
 if($FAIL_A3 > 0){
  print "values of n=1 and n=3 dihedral angles are not consistent: FAILED\n";
  $FAILED++;
 }else{
  print "values of n=1 and n=3 dihedral angles are consistent: PASSED\n";
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
 
 if($FAIL_LONGCONT>0){
  print "contacts were too long!!!  FAILED.\n";
  $FAILED++;
 }else{
  print "contact distances: PASSED\n";
 }


 if($model eq "AA"){
  if($NonstackingE !=0 && $stackingE !=0){
   my $CR=$NonstackingE/$stackingE;
   if($CR > $MAXTHR || $CR < $MINTHR){
    print "ratio between stacking and non stacking is not 1\n";
    print "ratio is $CR\n";
    $FAILED++;
   }else{
    print "ratio between stacking and non-stacking: PASSED\n";
   }
   if($FAIL_STACK>0 ){
    print "stacking interactions: FAILED\n";
    $FAILED++;
   }else{
    print "stacking interactions: PASSED\n";
   }
   if($FAIL_NONSTACK>0 ){
    print "non-stacking interactions: FAILED\n";
    $FAILED++;
   }else{
    print "non-stacking interactions: PASSED\n";
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
  if($AMINO_PRESENT){
   if(($PBBvalue/$PSCvalue > $MAXTHR*$R_P_BB_SC )  || ($PBBvalue/$PSCvalue < $MINTHR*$R_P_BB_SC ) ){
    print "protein backbone-to-sidechain dihedrals ratio is not correct: FAILED\n";
    $FAILED++;
   }else{
    print "protein backbone-to-sidechain dihedrals ratio: PASSED\n";
   }
  }
  if($NUCLEIC_PRESENT){
   if(($NABBvalue/$NASCvalue > $MAXTHR*$R_N_SC_BB )  || ($NABBvalue/$NASCvalue < $MINTHR*$R_N_SC_BB ) ){
    print "nucleic backbone-to-sidechain dihedrals ratio is not correct: FAILED\n";
    $FAILED++;
   }else{
    print "nucleic backbone-to-sidechain dihedrals ratio: PASSED\n";
   }
  }
  if($AMINO_PRESENT && $NUCLEIC_PRESENT){
   print "protein: $PBBvalue nucleic acid: $NABBvalue\n";
   my $RR=$PBBvalue/$NABBvalue;
   my $RR_TARGET=$PRO_DIH/$NA_DIH;
   print "Target ratio: $RR_TARGET\n";
   print "Actual ratio: $RR\n";
   if($RR > $MAXTHR*$RR_TARGET || $RR < $MINTHR*$RR_TARGET){
    print "backbone dihedrals are not consistent between nucleic acids and protein: FAILED\n";
    $FAILED++;
   }else{
    print "consistency between NA-protein backbone dihedrals: PASSED\n";
   }
  }
  if($AMINO_PRESENT && $LIGAND_PRESENT){
   print "protein: $PBBvalue Ligand: $LIGdvalue\n";
   my $RR=$PBBvalue/$LIGdvalue;
   my $RR_TARGET=$PRO_DIH/$LIGAND_DIH;
   print "Target ratio: $RR_TARGET\n";
   print "Actual ratio: $RR\n";
   if($RR > $MAXTHR*$RR_TARGET || $RR < $MINTHR*$RR_TARGET){
    print "backbone dihedrals are not consistent between ligands and protein: FAILED\n";
    $FAILED++;
   }else{
    print "consistency between ligand-protein backbone dihedrals: PASSED\n";
   }
  }
  if($LIGAND_PRESENT && $NUCLEIC_PRESENT){
   print "ligand: $LIGdvalue nucleic acid: $NABBvalue\n";
   my $RR=$LIGdvalue/$NABBvalue;
   my $RR_TARGET=$LIGAND_DIH/$NA_DIH;
   print "Target ratio: $RR_TARGET\n";
   print "Actual ratio: $RR\n";
   if($RR > $MAXTHR*$RR_TARGET || $RR < $MINTHR*$RR_TARGET){
    print "backbone dihedrals are not consistent between nucleic acids and ligand: FAILED\n";
    $FAILED++;
   }else{
    print "consistency between NA-ligand backbone dihedrals: PASSED\n";
   }
  }
  ## check if the range of dihedrals is reasonable  

  my $D_R=$DIH_MAX/ $DIH_MIN;
  if($D_R > $MAXTHR*4*$R_P_BB_SC  ){
   print "WARNING!!!: range of dihedrals is large\n";
  }else{
   print "range of dihedrals: PASSED\n";
  }

  print "ENERGIES: Contact=$CONTENERGY; Dihedral=$DENERGY\n";
  my $CD_ratio;
  if($DENERGY > 0){
   $CD_ratio=$CONTENERGY/$DENERGY;
  }else{
   $FAILED++;
   print "Dihedral energy is zero... FAIL\n";
  }
  if($MAXTHR*$R_CD < $CD_ratio || $MINTHR*$R_CD > $CD_ratio){
   print "The contact/dihedral ratio: FAILED\n";
   $FAILED++;
  }else{
   print "The contact/dihedral ratio: PASSED\n";
  }
 } 


 unless(open(CFILE,"$PDB.contacts")){
  print "can\'t open $PDB.contacts\n";
  $FAILED++;
 }
 my $NUMBER_OF_CONTACTS_SHADOW=0;
 while(<CFILE>){
  $NUMBER_OF_CONTACTS_SHADOW++;
 }
 
 
 if($FAIL_EXCLUSIONS > 0){
  print "exclusion-pair matching: FAILED\n";
  $FAILED++;
 }else{
  print "exclusion-pair matching: PASSED\n";
 }
  my $NRD=$NCONTACTS+$bondtype6;
 if($NUMBER_OF_CONTACTS_SHADOW != $NRD){
  $FAILED++;
  print "Same number of contacts not found in contact file and top file!!!! FAIL\n";
  printf ("%i contacts were found in the contact file.\n", $NUMBER_OF_CONTACTS_SHADOW);
  printf ("%i contacts were found in the top file.\n", $NRD);
 }
 my $E_TOTAL=$DENERGY+$CONTENERGY;
 my $CTHRESH=$NUMATOMS*10.0/$PRECISION;
 print "number of non-ligand atoms $NUMATOMS_LIGAND total E $E_TOTAL\n";
 if($model eq "AA"){ 
  if(abs($NUMATOMS_LIGAND-$E_TOTAL) > $CTHRESH){
   print "The total energy: FAILED\n";
   $FAILED++;
  }else{
   print "The total energy: PASSED\n";
  }
 }
}

sub summary
{
 if($FAILED > 0){
  print "\n*************************************************************\n";
  print "               $FAILED CHECKS FAILED FOR TEST $TESTNUM ($PDB)!!!\n";
  print  "*************************************************************\n";
  print "saving files with names $PDB.fail$TESTNUM.X\n";
  `cp share/PDB.files/$PDB.pdb $FAILDIR/$PDB.fail$TESTNUM.pdb`;

  foreach(@FILETYPES){
   if(-e "$PDB.$_"){
    `mv $PDB.$_ $FAILDIR/$PDB.fail$TESTNUM.$_`;
   }
   if(-e "$PDB.meta1.$_"){
    `mv $PDB.meta1.$_ $FAILDIR/$PDB.fail$TESTNUM.meta1.$_`;
   }
  }

  if($default ne "yes"){
   `mv temp.bifsif $FAILDIR/$PDB.fail$TESTNUM.bifsif`;
   if(-d "temp.cont.bifsif"){
    `mv temp.cont.bifsif $FAILDIR/$PDB.fail$TESTNUM.cont.bifsif`;
   }
  } 
  $NFAIL++;
  $FAIL_SYSTEM++;
 }else{
  print "\n*************************************************************\n";
  print "                 CHECK $TESTNUM PASSED ($PDB)\n";
  print  "*************************************************************\n";
  foreach(@FILETYPES){
   if(-e "$PDB.$_"){
    `rm $PDB.$_`;
   }
   if(-e "$PDB.meta1.$_"){
    `rm $PDB.meta1.$_`;
   }
  }
 }
}

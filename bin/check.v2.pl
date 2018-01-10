use strict;
use warnings;
use smog_common;
use check_common;
# This is the main script that runs SMOG2 and then checks to see if the generated files are correct.
# This is intended to be a brute-force evaluation of everything that should appear. Since this is
# a testing script, it is not designed to be efficient, but to be thorough, and foolproof...
print <<EOT;
*****************************************************************************************
                                       smog-check                                   

       smog-check is part of the SMOG 2 distribution, available at smog-server.org     

       This tool will check your installation of SMOG 2, to ensure that a number of
                         models are being constructed properly.

                       See the SMOG manual for usage guidelines.

            For questions regarding this script, contact info\@smog-server.org              
*****************************************************************************************
EOT


# check if we are simply rerunning a single test, or performing all
my $RETEST=$#ARGV;
if($RETEST == 0){
	if($ARGV[0] =~ /^\d+$/){
		# is an integer
		$RETEST=$ARGV[0];
		print "\nWill only run test $ARGV[0].\n\n";
	}else{
		# is not an integer.  flag error
		smogcheck_error("argument to smog-check must be an integer. Found \"$ARGV[0]\"");
	}

}elsif($RETEST== -1){
	print "\nWill run all tests (default).\n\n";
}else{
	smogcheck_error("Too many arguments passed to smog-check");
}

# rerun rend

&checkForModules;
 
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

# FAILLIST is a list of all the tests.
# If you are developing and testing your own forcefield, which may not need to conform to certain checks, then you may want to disable some tests by  removing the test name from this list. However, do so at your own risk.
our @FAILLIST = ('NAME','DEFAULTS, nbfunc','DEFAULTS, comb-rule','DEFAULTS, gen-pairs','1 MOLECULE','ATOMTYPES UNIQUE','ALPHANUMERIC ATOMTYPES','ONLY 1 ATOMTYPE','TOP FIELDS FOUND','MASS', 'CHARGE','moleculetype=Macromolecule','nrexcl=3', 'PARTICLE', 'C6 VALUES', 'C12 VALUES', 'SUPPORTED BOND TYPES', 'OPEN GRO','GRO-TOP CONSISTENCY', 'BOND STRENGTHS', 'ANGLE TYPES', 'ANGLE WEIGHTS', 'DUPLICATE BONDS', 'DUPLICATE ANGLES', 'ANGLE CONSISTENCY 1','ANGLE CONSISTENCY 2','ANGLE CONSISTENCY 3', 'IMPROPER WEIGHTS', 'CA IMPROPERS EXIST','OMEGA IMPROPERS EXIST','SIDECHAIN IMPROPERS EXIST','CA DIHEDRAL WEIGHTS', 'DUPLICATE TYPE 1 DIHEDRALS','DUPLICATE TYPE 2 DIHEDRALS','DUPLICATE TYPE 3 DIHEDRALS','1-3 DIHEDRAL PAIRS','3-1 DIHEDRAL PAIRS','1-3 ORDERING OF DIHEDRALS','1-3 DIHEDRAL RELATIVE WEIGHTS','STRENGTHS OF RIGID DIHEDRALS','STRENGTHS OF OMEGA DIHEDRALS','STRENGTHS OF PROTEIN BB DIHEDRALS','STRENGTHS OF PROTEIN SC DIHEDRALS','STRENGTHS OF NUCLEIC BB DIHEDRALS','STRENGTHS OF NUCLEIC SC DIHEDRALS','STRENGTHS OF LIGAND DIHEDRALS','STACK-NONSTACK RATIO','PROTEIN BB/SC RATIO','NUCLEIC SC/BB RATIO','AMINO/NUCLEIC DIHEDRAL RATIO','AMINO/LIGAND DIHEDRAL RATIO','NUCLEIC/LIGAND DIHEDRAL RATIO','NONZERO DIHEDRAL ENERGY','CONTACT/DIHEDRAL RATIO','1-3 DIHEDRAL ANGLE VALUES','DIHEDRAL CONSISTENCY 1','DIHEDRAL CONSISTENCY 2','STACKING CONTACT WEIGHTS','NON-STACKING CONTACT WEIGHTS','LONG CONTACTS', 'CA CONTACT WEIGHTS', 'CONTACT DISTANCES','GAUSSIAN CONTACT WIDTHS','GAUSSIAN CONTACT EXCLUDED VOLUME','CONTACTS NUCLEIC i-j=1','CONTACTS PROTEIN i-j=4','CONTACTS PROTEIN i-j!<4','SCM MAP GENERATED','SCM CONTACT COMPARISON','NUMBER OF EXCLUSIONS', 'BOX DIMENSIONS','GENERATION OF ANGLES/DIHEDRALS','OPEN CONTACT FILE','NCONTACTS','TOTAL ENERGY','TYPE6 ATOMS','UNINITIALIZED VARIABLES','CLASSIFYING DIHEDRALS','NON-ZERO EXIT');



my %supported_directives = ( 'defaults' => '0',
        'atomtypes' => '1',
        'moleculetype' => '0',
        'nonbond_params' => '0',
        'atoms' => '1',
        'bonds' => '1',
        'angles' => '1',
        'dihedrals' => '1',
        'pairs' => '1',
        'exclusions' => '1',
        'system' => '1',
        'molecules' => '1',
        'position_restraints' => '1'
        );


unless(-d $BIFSIF_AA && -d $BIFSIF_CA && -d $TEMPLATE_DIR_AA && -d $TEMPLATE_DIR_AA_STATIC && -d $TEMPLATE_DIR_CA ){
 smogcheck_error("Can\'t find the template directories. Something is wrong with the configurations of this script.\nYour intallation of SMOG2 may be ok, but we can\'t tell\nGiving up...");
}

# default location of test PDBs
our $PDB_DIR="share/PDB.files";
print "environment variables read\n";
print "EXEC_NAME $EXEC_NAME\n";

# where should data from failed tests be written
our $FAILDIR="FAILED";


our @FILETYPES=("top","gro","ndx","settings","contacts","output","contacts.SCM", "contacts.CG");

unless( -e $SCM){
 smogcheck_error("Can\'t find Shadow!");
}
our %BBTYPE;
## read in the backbone atom types.  Remember, CA and C1* can be involved in sidechain dihedrals
open(BBAMINO,"share/backboneatoms/aminoacids") or internal_error("no amino acid file");
while(<BBAMINO>){
 my $LINE=$_;
 chomp($LINE);
 $LINE =~ s/\s+$//;
 $BBTYPE{$LINE}= "BACKBONE";
}

open(BBNUCLEIC,"share/backboneatoms/nucleicacids") or internal_error("no amino acid file");
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
open(AMINO,"share/residues/aminoacids") or internal_error("no amino acid file");
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
open(NUCLEIC,"share/residues/nucleicacids") or internal_error("no nucleic acid file");
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
open(LIGAND,"share/residues/ligands") or internal_error("no nucleic acid file");
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
open(ION,"share/residues/ions") or internal_error("no ion file");
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
 

# a number of global variables.
our $default;
our $gaussian;
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
our %FAIL;
our $rep_s12;
our @ATOMNAME;
our @GRODATA;
our @ATOMTYPE;
our @RESNUM;
our @MOLTYPE;
our %MOLTYPEBYRES;
our %restypecount;
our $bondEps;
our $bondMG;
our $angleEps;
our $ringEps;
our $omegaEps;
our $impEps;
our $DENERGY;
our @ED_T;
our @EDrig_T;
our $DISP_MAX=0;
our $CONTENERGY;
our ($theta_gen_N,$phi_gen_N,$improper_gen_N);
#our ($NonstackingE,$stackingE);
our @XT;
our @YT;
our @ZT;
our $bondtype6;
our $type6count;
our $fail_log;
my $NUMTESTED=0;
my $SETTINGS_FILE=<STDIN>;
chomp($SETTINGS_FILE);
open(PARMS,"$SETTINGS_FILE") or internal_error("The settings file is missing...");
my $TESTNUM=0;
## Run tests for each pdb
while(<PARMS>){
 my $LINE=$_;
 chomp($LINE);
 $LINE =~ s/\s+/ /g;
 $LINE =~ s/\s+$//;
 $LINE =~ s/^\s+//;
 $fail_log="";
 $FAILED=0;
 my @A=split(/ /,$LINE);
 $PDB=$A[0];
 $TESTNUM++;
 if($RETEST>0 and $RETEST != $TESTNUM){
  next;
 }
 $NUMTESTED++;
 unless(-e "$PDB_DIR/$PDB.pdb"){
  print "Unable to find PDB file $PDB_DIR/$PDB.pdb for testing.  Skipping this test\n\n";
  $FAIL_SYSTEM++;
  next;
 }
  print "\n*************************************************************\n";
  print "                 STARTING TEST $TESTNUM ($PDB)\n";
  print "*************************************************************\n";
  undef  $CONTTYPE;
  undef  $CONTD;
  undef  $CONTR;
  undef  $BBRAD;
  undef  $R_CD;
  undef  $R_P_BB_SC;
  undef  $R_N_SC_BB;
  undef  $PRO_DIH;
  undef  $NA_DIH;
  undef  $LIGAND_DIH;
  undef  $sigma;
  undef  $epsilon;
  undef  $epsilonCAC;
  undef  $epsilonCAD;
  undef  $sigmaCA;


 $model=$A[1];
 if($A[2] =~ m/^default$/){
  $default="yes";
  $gaussian="no";
 }elsif($A[2] =~ m/^default-gaussian$/){
  print "Will use gaussian contacts\n";
  $default="yes";
  $gaussian="yes";
 }elsif($A[2] =~ m/^cutoff$/){
  print "Will use cutoff contacts\n";
  $default="no";
  $gaussian="no";
 }elsif($A[2] =~ m/^shadow$/){
  print "Will use shadow contacts\n";
  $default="no";
  $gaussian="no";
 }elsif($A[2] =~ m/^shadow-gaussian$/ || $A[2] =~ m/^cutoff-gaussian$/){
  print "Will use gaussian contacts\n";
  $default="no";
  $gaussian="yes";
 }else{
  smogcheck_error("Unknown contact option: \"$A[2]\"");
 }
 if($model =~ m/CA/){
  print "Testing CA model\n";
 }elsif($model =~ m/AA/){
  print "Testing AA model\n";
 }else{
  smogcheck_error("Model name $model, not understood. Only CA and AA models are supported by the test script.");
 }
# clean up the tracking for the next test
 foreach my $item(@FAILLIST){
  $FAIL{$item}=1;
 }

 if($default eq "yes"){
  print "Checking default parameters\n";
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
  $epsilon=0.1;
  $epsilonCAC=1.0;
  $epsilonCAD=1.0;
  $sigmaCA=4.0;
 }else{
  print "Checking non-default parameters for SMOG models\n";
  my $ARG=2;
  # energy distributions
  # map type
  $CONTTYPE=$A[$ARG];
  $ARG++;
  if($CONTTYPE =~ m/^shadow$/){
   print "Will generate and use a shadow map\n";
   $CONTD=$A[$ARG];
   $ARG++;
   $CONTR=$A[$ARG];
   $ARG++;
   $BBRAD=0.5;
  }elsif($CONTTYPE =~ m/^cutoff$/){
   print "Will generate and use a cutoff map\n";
   $CONTD=$A[$ARG];
   $ARG++;
   $CONTR=0.0;
   $BBRAD=0.0;
  }elsif($CONTTYPE =~ m/^cutoff-gaussian$/){
   print "Will generate and use a cutoff map and gaussian contacts\n";
   $CONTD=$A[$ARG];
   $ARG++;
   $CONTR=0.0;
   $BBRAD=0.0;
  }elsif($CONTTYPE =~ m/^shadow-gaussian$/){
   print "Will generate and use a shadow map and gaussian contacts\n";
   $CONTD=$A[$ARG];
   $ARG++;
   $CONTR=$A[$ARG];
   $ARG++;
   $BBRAD=0.5;
  }else{
   smogcheck_error("Contact scheme $CONTTYPE is not supported. Is there a typo in $PDB_DIR/$PDB.pdb?");
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
  if(!exists $A[$ARG]){
   smogcheck_error("Insufficient number of arguments given in settings file for smog-check.");
  }
 }

 if($model =~ m/CA/){
  $bondEps=20000;
  $angleEps=40;
 }elsif($model =~ m/AA/){
  $bondEps=10000;
  $angleEps=80;
 }else{
  smogcheck_error("Model name $model, not understood. Only CA and AA models are supported by the test script.");
 }

 $bondMG=200;
 $ringEps=40;
 $omegaEps=10;
 $impEps=10;

 &smogchecker;

}

 # If any systems failed, output message
 if($FAIL_SYSTEM > 0){
  print <<EOT;
*************************************************************
             TESTS FAILED: CHECK MESSAGES ABOVE  !!!
************************************************************* 
EOT
  exit(1);
 }elsif($NUMTESTED == 0){
  print <<EOT;
*************************************************************
                      NO TESTS PERFORMED !!!
*************************************************************
EOT
  exit(1);
 }elsif($RETEST < 0){
  print <<EOT;
*************************************************************
                      PASSED ALL TESTS  !!!
*************************************************************
EOT
  exit(0);
 }elsif($RETEST > 0){
  exit(0);
 }

sub runsmog
{
 my $ARGS=" -i $PDB_DIR/$PDB.pdb -g $PDB.gro -o $PDB.top -n $PDB.ndx -s $PDB.contacts";

# prepare the flags
 if($default eq "yes"){
  if($model eq "CA" && $gaussian eq "no"){
   $ARGS .= " -CA";
  }elsif($model eq "CA" && $gaussian eq "yes"){
   $ARGS .= " -CAgaussian";
  }elsif($model eq "AA" &&  $gaussian eq "no"){
   $ARGS .= " -AA";
  }elsif($model eq "AA" &&  $gaussian eq "yes"){
   $ARGS .= " -AAgaussian";
  }else{
   smogcheck_error("unrecognized model.");
  }
 }else{
  if($model eq "CA"){
   $ARGS .= " -tCG temp.bifsif/  -t temp.cont.bifsif";
  }elsif($model eq "AA"){
   $ARGS .= " -t temp.bifsif/ ";
  }else{
   smogcheck_error("unrecognized model.");
  }
 }

# run smog2
 `$EXEC_NAME $ARGS &> $PDB.output`;
}


sub checkSCM
{
 if($model eq "AA"){
  my $SHADOWARGS="-g $PDB.gro -t $PDB.top -ch $PDB.ndx -o $PDB.contacts.SCM -m shadow -c $CONTD -s $CONTR -br $BBRAD";
  if($default eq "yes"){
   $SHADOWARGS .= " -bif $BIFSIF_AA/AA-whitford09.bif";
  }elsif($default eq "no"){
   $SHADOWARGS .= " -bif temp.bifsif/tmp.bif";
  }else{
   internal_error('SCM DEFAULT TESTING');
  }
  `java -jar $SCM $SHADOWARGS &> $PDB.meta2.output`;

 }elsif($model eq "CA"){
  # run AA model to get top
  `$EXEC_NAME -i $PDB_DIR/$PDB.pdb -g $PDB.meta1.gro -o $PDB.meta1.top -n $PDB.meta1.ndx -s $PDB.meta1.contacts -t $BIFSIF_AA  &> $PDB.meta1.output`;

  my $SHADOWARGS="-g $PDB.meta1.gro -t $PDB.meta1.top -ch $PDB.meta1.ndx -o $PDB.contacts.SCM -m shadow -c $CONTD -s $CONTR -br $BBRAD";

  if($default eq "yes"){
   $SHADOWARGS .= " -bif $BIFSIF_AA/AA-whitford09.bif";
  }elsif($default eq "no"){
   $SHADOWARGS .= " -bif temp.cont.bifsif/tmp.cont.bif";
  }else{
   internal_error('SCM CA DEFAULT TESTING');
  }

  # run SCM to get map
  `java -jar $SCM $SHADOWARGS &> $PDB.meta3.output`;
 }

 # check that the same contact map is generated
 my $CONTDIFF=filediff("$PDB.contacts","$PDB.contacts.SCM");
 if($CONTDIFF == 0){
  $FAIL{'SCM CONTACT COMPARISON'}=0;
 }

 if(-e "$PDB.contacts.SCM"){
  $FAIL{'SCM MAP GENERATED'}=0;
 } 
}

sub smogchecker
{

 &cleanoldfiles;
 &preparesettings;
 &runsmog; 

 ($FAIL{'NON-ZERO EXIT'},$FAIL{'UNINITIALIZED VARIABLES'})=checkoutput("$PDB.output");

 if($FAIL{'UNINITIALIZED VARIABLES'} == 1){
  $fail_log .= failed_message("SMOG 2 encountered uninitialized variables.");
 }

 if($FAIL{'NON-ZERO EXIT'} == 0){
  print "SMOG 2 exited without an error.\nAssessing generated files...\n";
  # CHECK THE OUTPUT
  &checkSCM;
  &checkgro; 
  &checkndx;
  &readtop;
  &checkvalues;
 }else{
  $fail_log .= failed_message("SMOG 2 exited with non-zero exit code when trying to process this PDB file.");
  $FAIL_SYSTEM++;
 }
 &summary; 
}

sub checkgro
{
 if(open(GRO,"$PDB.gro")){
  $FAIL{'OPEN GRO'}=0;
 }else{
  smogcheck_error("$PDB.gro can not be opened. This means SMOG died unexpectedly.");
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
 $DX=int($DX * $PRECISION/10.0)/($PRECISION*0.1);
 $DY=int($DY * $PRECISION/10.0)/($PRECISION*0.1);
 $DZ=int($DZ * $PRECISION/10.0)/($PRECISION*0.1);
 my $t1=int(abs($BOUNDS[0]-$DX)* $PRECISION/10.0)/($PRECISION*0.1);
 my $t2=int(abs($BOUNDS[1]-$DY)* $PRECISION/10.0)/($PRECISION*0.1);
 my $t3=int(abs($BOUNDS[2]-$DZ)* $PRECISION/10.0)/($PRECISION*0.1);
 if($t1 > $TOLERANCE || $t2 > $TOLERANCE || $t3 > $TOLERANCE ){
  $fail_log .= failed_message("Gro box size inconsistent\n\t$BOUNDS[0],$XMAX,$XMIN,$BOUNDS[1],$YMAX,$YMIN,$BOUNDS[2],$ZMAX,$ZMIN,$t1,$t2,$t3");
 }else{
  $FAIL{'BOX DIMENSIONS'}=0;
 }
}

sub preparesettings
{
 # make a log of the settings being used for this test
my $string = <<"EOT";
Here are the settings used for this test
$PDB.pdb
$PDB.top
$PDB.gro
$PDB.ndx
All-Atom
R_CD 	   $R_CD
R_P_BB_SC  $R_P_BB_SC
R_N_SC_BB  $R_N_SC_BB
PRO_DIH    $PRO_DIH
NA_DIH     $NA_DIH
LIGAND_DIH $LIGAND_DIH
sigma 	   $sigma 
epsilon    $epsilon
epsilonCAC $epsilonCAC
epsilonCAD $epsilonCAD
sigmaCA    $sigmaCA
EOT
 open(READSET,">$PDB.settings") or internal_error("can not open settings file");
 print READSET "$string";
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
  smogcheck_error("unknown model type.");
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
  if($CONTTYPE eq "shadow"){
   `sed "s/CUTDIST/$CONTD/g;s/SCM_R/$CONTR/g;s/SCM_BR/$BBRAD/g" $TEMPLATE_DIR_AA_STATIC/*.shadow.sif > temp.cont.bifsif/tmp.cont.sif`;
  }elsif($CONTTYPE eq "cutoff"){
   `sed "s/CUTDIST/$CONTD/g" $TEMPLATE_DIR_AA_STATIC/*.cutoff.sif > temp.cont.bifsif/tmp.cont.sif`;
  }
 } 

 if($model eq "AA" && $default ne "yes"){
  `mkdir temp.bifsif`;
  my $PARM_P_BB=$PRO_DIH;
  my $PARM_P_SC=$PRO_DIH/$R_P_BB_SC;
  my $PARM_N_BB=$NA_DIH;
  my $PARM_N_SC=$NA_DIH*$R_N_SC_BB;
  if($CONTTYPE eq "shadow"){
   `sed "s/PARM_C_D/$R_CD/g;s/PARM_P_BB/$PARM_P_BB/g;s/PARM_P_SC/$PARM_P_SC/g;s/PARM_N_BB/$PARM_N_BB/g;s/PARM_N_SC/$PARM_N_SC/g;s/CUTDIST/$CONTD/g;s/SCM_R/$CONTR/g;s/SCM_BR/$BBRAD/g" $TEMPLATE_DIR_AA/*.shadow.sif > temp.bifsif/tmp.sif`;
  }elsif($CONTTYPE eq "cutoff"){
   `sed "s/PARM_C_D/$R_CD/g;s/PARM_P_BB/$PARM_P_BB/g;s/PARM_P_SC/$PARM_P_SC/g;s/PARM_N_BB/$PARM_N_BB/g;s/PARM_N_SC/$PARM_N_SC/g;s/CUTDIST/$CONTD/g" $TEMPLATE_DIR_AA/*.cutoff.sif > temp.bifsif/tmp.sif`;
  }
  `sed "s/PARM_C12/$rep_s12/g" $TEMPLATE_DIR_AA/*.nb > temp.bifsif/tmp.nb`;
  `cp $TEMPLATE_DIR_AA/*.bif temp.bifsif/tmp.bif`;
  `cp $TEMPLATE_DIR_AA/*.b temp.bifsif/tmp.b`;
 }
}


sub checkndx
{

 open(NDX,"$PDB.ndx") or internal_error(" $PDB.ndx can not be opened...");
 open(NDX2,">$PDB.ndx2") or internal_error(" $PDB.ndx2 can not be opened...");
 while(<NDX>){
  my $LINE=$_;
  chomp($LINE);
  $LINE =~ s/^\s+|^\t+//g;
  if($LINE =~ m/^;/){
   next;
  }
  $LINE =~ s/;.*$//g;
  $LINE =~ s/\t/ /g;
  $LINE =~ s/\s+$//g;
  $LINE =~ s/\s+/ /g;
  if($LINE eq ""){
   next;
  }
  print NDX2 "$LINE\n";
 }
 close(NDX);
 close(NDX2);
 `mv $PDB.ndx2 $PDB.ndx`;
 open(NDX,"$PDB.ndx") or internal_error("no ndx file"); 
 my $CHAIN;
 while(<NDX>){
  my $LINE=$_;        
  chomp($LINE);
  $LINE =~ s/;.*$//g;
  $LINE =~ s/\t/ /g;
  $LINE =~ s/^\s+|\s+$//g;
  $LINE =~ s/\s+/ /g;
  my @A=split(/ /,$LINE);
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
 $DIH_MIN=100000000;
 $DIH_MAX=-100000000;
 $NCONTACTS=0;
 # clean up top file for easy parsing later
 open(TOP,"$PDB.top") or internal_error(" $PDB.top can not be opened...");
 open(TOP2,">$PDB.top2") or internal_error(" $PDB.top can not be opened...");
 while(<TOP>){
  my $LINE=$_;
  chomp($LINE);
  my ($A,$B)=checkcomment($LINE);
  if($A eq ""){
   next;
  }
  print TOP2 "$A\n";
 }
 close(TOP);
 close(TOP2);
 `mv $PDB.top2 $PDB.top`;
 open(TOP,"$PDB.top") or internal_error(" $PDB.top can not be opened...");
 $NUCLEIC_PRESENT=0;
 $AMINO_PRESENT=0;
 $LIGAND_PRESENT=0;
 $ION_PRESENT=0;
 undef %MOLTYPEBYRES;
 undef %restypecount;
 my @theta_gen;
 my @PAIRS;
 my %dihedral_array1;
 my %dihedral_array2;
 my %dihedral_array3;
 my %dihedral_array1_W;
 my %dihedral_array3_W;
 my %dihedral_array1_A;
 my %dihedral_array3_A;
 my $finalres;
 my %revData;
 my @resindex;
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
 my $stackingE=0;
 my $NonstackingE=0;
 while(<TOP>){
  my $LINE=$_;
  chomp($LINE);
  @A=split(/ /,$LINE);
  if(exists $A[1]){
   if($A[1] eq "defaults"){
    $FOUND{'defaults'}++;
    $LINE=<TOP>;
    chomp($LINE);
    @A=split(/ /,$LINE);
    if($A[0] == 1){
     $FAIL{'DEFAULTS, nbfunc'}=0; 
    }else{
     $fail_log .= failed_message("default nbfunc is not correctly set.");
    }
    if($A[1] == 1){
     $FAIL{'DEFAULTS, comb-rule'}=0; 
    }else{
     $fail_log .= failed_message("default comb-rule is not correctly set.");
    }
    if($A[2] eq "no"){
     $FAIL{'DEFAULTS, gen-pairs'}=0; 
    }else{
     $fail_log .= failed_message("default gen-pairs is not correctly set.");
    }
   }
  }
  if(exists $A[1]){
   if($A[1] eq "atomtypes"){
    $FOUND{'atomtypes'}++;
    $#A = -1;
    $LINE=<TOP>;
    chomp($LINE);
    @A=split(/ /,$LINE);
    my %seen;
    my $numtypes=0;
    my $mass1=0;
    my $typesunique=0;
    my $acceptablenames=0;
    my $charge1=0;
    my $particle1=0;
    my $c61=0;
    my $excl1=0;
    until($A[0] eq "["){
     $numtypes++;
     if(!exists $seen{$A[0]}){
      $seen{$A[0]}=1;
      $typesunique++;
     }else{
      my $T=$A[0];
      smogcheck_error("atomtype name $T appears more than once.");
     }
     if($A[0] =~ /^[a-zA-Z0-9_]+$/){
      $acceptablenames++;
     }else{
      my $T=$A[0];
      smogcheck_error("Only letters, numbers and _ can appear in atomtype names. atomtype $T found.");
     }
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
    if($numtypes == $typesunique and $typesunique !=0){
     $FAIL{'ATOMTYPES UNIQUE'}=0;
    }
    if($numtypes ==1){
     $FAIL{'ONLY 1 ATOMTYPE'}=0;
    }
    if($numtypes == $acceptablenames and $acceptablenames !=0){
     $FAIL{'ALPHANUMERIC ATOMTYPES'}=0;
    }
   }
  } 
  if(exists $A[1]){
   # check the excluded volume is consistent with the settings.
   if($A[1] eq "moleculetype"){
    $FOUND{'moleculetype'}++;
    my $LINE=<TOP>;
    chomp($LINE); 
    @A=split(/ /,$LINE);
    if($A[0] eq "Macromolecule"){
     $FAIL{'moleculetype=Macromolecule'}=0;
    }else{
     $fail_log .= failed_message("default molecule name is different than expected");
    }
    if($A[1] == 3){
     $FAIL{'nrexcl=3'}=0;
    }else{
     $fail_log .=failed_message("nrexcl is not set to 3.");
    }
   }
  } 
  if(exists $A[1]){
   # read the atoms, and store information about them
    my $FAIL_GROTOP=0;
   if($A[1] eq "atoms"){
    $FOUND{'atoms'}++;
    $NUMATOMS=0;
    $NUMATOMS_LIGAND=0;
    $#A = -1;
    $LINE=<TOP>;
    @A=split(/ /,$LINE);
    until($A[0] eq "["){
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
     $resindex[$A[0]]=$A[2];
     $finalres=$A[2];
     my $label=sprintf("%i-%s", $A[2], $A[4]);
     $revData{$label}=$A[0];
    # nucleic acid, protein, ligand
     if(defined $TYPE{$A[3]}){
      $MOLTYPE[$A[0]]=$TYPE{$A[3]};
      $MOLTYPEBYRES{$A[2]}=$TYPE{$A[3]};
     }else{
      internal_error("there is an unrecognized residue name at $A[0] $A[3]");
     }
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
     }
     $NUMATOMS++;
     $#A = -1;
     $LINE=<TOP>;
     last unless defined $LINE;
     @A=split(/ /,$LINE);
    }
    if($FAIL_GROTOP ==0){
     $FAIL{'GRO-TOP CONSISTENCY'}=0;
    }
   # count the number of amino residue, nucleic residues, ligand residues and ions
    foreach my $rest(keys %MOLTYPEBYRES){
     $restypecount{$MOLTYPEBYRES{$rest}}++;
    }
   }
  }
  if(exists $A[1]){  
   # read the bonds.  Make sure they are not assigned twice.  Also, save the bonds, so we can generate all possible bond angles later.
   if($A[1] eq "bonds"){
    $FOUND{'bonds'}++;
    $#A = -1;
    my @bonds;
    $#bonds = -1;
    my @bondWatom;
    $#bondWatom = -1;
    my @NbondWatom;
    $#NbondWatom = -1;
    my $doublebond=0;
    $bondtype6=0;
    $type6count=0;
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
    @A=split(/ /,$LINE);
    until($A[0] eq "["){
     $NBONDS++;
     if($A[2] == 1){
      $RECOGNIZEDBTYPES++;
      if($A[4] != $bondEps){
       $fail_log .= failed_message("bond has incorrect weight\n\t$LINE");
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
     }elsif($A[2] == 6){
      $RECOGNIZEDBTYPES++;
      $bondtype6++;
      if($ATOMNAME[$A[0]] eq "BMG" or $ATOMNAME[$A[1]] eq "BMG"){
       $type6count++; 
      }else{
       $fail_log .= failed_message("type 6 bond between non-BMG atoms: $ATOMNAME[$A[0]] $A[0], and $ATOMNAME[$A[1]] $A[1].");
      } 
       if($A[4] != $bondMG){
        $fail_log .= failed_message("BMG bond has incorrect weight\n\t$LINE");
       }else{
       $CORRECTBONDWEIGHTS++;
      }		
     }else{
      $fail_log .= failed_message("unknown function type for bond\n\t$LINE");
     }
     $LINE=<TOP>;
     last unless defined $LINE;
     @A=split(/ /,$LINE);
    }

    if($doublebond ==0){
     $FAIL{'DUPLICATE BONDS'}=0;
    }
    if($bondtype6 == 0){
     $FAIL{'TYPE6 ATOMS'}=-1;
    }elsif($bondtype6 == $type6count){
     $FAIL{'TYPE6 ATOMS'}=0;
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
    $FOUND{'angles'}++;
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
     $FAIL{'ANGLE CONSISTENCY 1'}=0;
    }else{
     $fail_log .= failed_message("The number of generated angles is inconsistent with the number of angles in the top file\n\tgenerated: $theta_gen_N, found: $Nangles");
     $FAIL{'ANGLE CONSISTENCY 1'}=1;
    }
    my $CONangles=0;
    # check to see if all the generated angles (from this script) are present in the top file
    for(my $i=0;$i<$theta_gen_N;$i++){
     if(exists $angle_array{$theta_gen[$i]} ){
       $CONangles++;
      }else{
       $fail_log .= failed_message("angle generated, but not in top: $theta_gen[$i]");
     }
    }
    if($CONangles == $theta_gen_N){
     $FAIL{'ANGLE CONSISTENCY 2'}=0;
    }else{
     $FAIL{'ANGLE CONSISTENCY 2'}=1;
    }

    $CONangles=0;
    # check to see if all top angles are present in the generate list.
    for(my $i=0;$i<$Nangles;$i++){
     if(exists $theta_gen_as{$angles1[$i]}){
      $CONangles++;
     }else{
      $fail_log .= failed_message("angle in top, but not generated: $angles1[$i]");
     }
    }
     if($CONangles == $Nangles){
     $FAIL{'ANGLE CONSISTENCY 3'}=0;
    }else{
     $FAIL{'ANGLE CONSISTENCY 3'}=1;
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
    $FOUND{'dihedrals'}++;
    if($model ne "CA" ){
     $FAIL{'CA DIHEDRAL WEIGHTS'}=-1;
    }
    $DENERGY=0;
    my $doubledih1=0;
    my $doubledih2=0;
    my $doubledih3=0;
    my $Nphi=0;
    my $solitary3=0;
    my $S3_match=0;
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
        $dihedral_array3_W{$string}=$A[6];
        $dihedral_array3_A{$string}=$A[5];
        $accounted++;
	if(!exists $dihedral_array3{$string}){
         $solitary3++;
         $fail_log .= failed_message("Type 3 dihedral appeared w/o a type 1...\n\t$LINE");
        }
       }elsif(exists $dihedral_array3{$string} and exists $A[7] and $A[7] == 3){
        $doubledih3++; 
        $fail_log .= failed_message("Duplicate dihedral\n\t$LINE");
       }elsif(!exists $dihedral_array1{$string} and exists $A[7] and $A[7] == 1){
	#check duplicate type 1 and 2
        ## dihedral was not assigned.
        $dihedral_array1{$string}=1;
        $dihedral_array1_W{$string}=$A[6];
        $dihedral_array1_A{$string}=$A[5];
        $accounted++;
        $accounted1++;
       }elsif(exists $dihedral_array1{$string} and exists $A[7] and $A[7] == 1){
        $doubledih1++;
        $fail_log .= failed_message("Duplicate dihedral\n\t$LINE");
       }elsif(!exists $dihedral_array2{$string} and $A[4] == 2){
        $dihedral_array2{$string}=1;
        $accounted++;
       }elsif(exists $dihedral_array2{$string} and $A[4] == 2){
        $doubledih2++;
        $fail_log .= failed_message("Duplicate dihedral\n\t$LINE");
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
      $LAST_N=$A[7];
      if($A[7] == 3 && ($string eq $string_last)){
       $S3_match++; 
      }
      if($A[4] == 1 && $A[7] == 1 ){
       my $F;
       if($model eq "CA"){
        if(($A[6] > $MINTHR*$epsilonCAD && $A[6] < $MAXTHR*$epsilonCAD)){
         $DIHSW++;
        }elsif(($A[6] < $MINTHR*$epsilonCAD || $A[6] > $MAXTHR*$epsilonCAD)){
         $fail_log .= failed_message("error in dihedral strength on line:$LINE\n");
        }
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
       $fail_log .= failed_message("improper dihedral has wrong weight\n\t$LINE");
      }
     }

     $#A = -1;
     $LINE=<TOP>;
     last unless defined $LINE;
     @A=split(/ /,$LINE);
    }


    # All dihedrals read in.  Now do checking

    my $CONdihedrals=0;
    # check to see if all top angles are present in the generate list.
    for(my $i=0;$i<$Nphi;$i++){
     if(exists $phi_gen_as{$phi[$i]} or exists $improper_gen_as{$phi[$i]} ){
      $CONdihedrals++;
     }else{
      $fail_log .= failed_message("dihedral appearing in top, but does not match a proper/improper generated by script: $phi[$i]");
     }
    }
     if($CONdihedrals == $Nphi){
     $FAIL{'DIHEDRAL CONSISTENCY 1'}=0;
    }else{
     $FAIL{'DIHEDRAL CONSISTENCY 1'}=1;
    }

    my $gen_match=0;
    # check to see if all the generated dihedrals (from this script) are present in the top file
    for(my $i=0;$i<$phi_gen_N;$i++){
     if(exists $dihedral_array1{$phi_gen[$i]}  or exists $dihedral_array2{$phi_gen[$i]} ){
      $gen_match++;
     }else{
      $fail_log .= failed_message("Generated dihedral $phi_gen[$i] is not in the list of included dihedrals...");
     }
    }
    if($gen_match==$phi_gen_N){
     $FAIL{'DIHEDRAL CONSISTENCY 2'}=0;
    }

    if($CORIMP == 0){
     $FAIL{'IMPROPER WEIGHTS'}=0;
    } 
    if($model eq "CA"){
     if($Nphi/2 == $DIHSW){
      $FAIL{'CA DIHEDRAL WEIGHTS'}=0;
     }else{
      $fail_log .= failed_message("ISSUE with CA dihedral weights\n\t$Nphi $DIHSW");
     }
    }
    if($Nphi == $accounted and $Nphi != 0){
     $FAIL{'CLASSIFYING DIHEDRALS'}=0;
    }else{
     $fail_log .= failed_message("ISSUE classifying dihedrals\n\t$Nphi $DIHSW");
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
    my $matchingpairs_W=0;
    my $matchingpairs_A=0;
    my $tt1;
    my $tt2;
    foreach my $pair (keys %dihedral_array1){
     if(exists $dihedral_array3{$pair}){
      $matchingpairs++;
      if($dihedral_array3_W{$pair}  > $MINTHR*0.5*$dihedral_array1_W{$pair} and $dihedral_array3_W{$pair}  < $MAXTHR*0.5*$dihedral_array1_W{$pair}  ){
       $matchingpairs_W++;
      }else{
       $fail_log .= failed_message("Relative weight between a N=1 and N=3 dihedral is not consistent: $pair, $dihedral_array1_W{$pair}, $dihedral_array3_W{$pair}");
      }
      my $angle1=$dihedral_array1_A{$pair};
      my $angle3=$dihedral_array3_A{$pair};
      if((($angle3 % 360.0) > $MINTHR*(3*$angle1 % 360.0) and ($angle3 % 360.0) < $MAXTHR*(3*$angle1 % 360.0)) or (($angle3 % 360.0) < ($MAXTHR-1) and (3*$angle1 % 360.0) < ($MAXTHR-1) )){
       $matchingpairs_A++;
      }else{
       $fail_log .= failed_message("Relative angles between a N=1 and N=3 dihedral is not consistent: $pair,$angle1,$angle3");
      }
     }
    }
    if($matchingpairs == $accounted1){
     $FAIL{'1-3 DIHEDRAL PAIRS'}=0
    }
    if($S3_match == $accounted1){
     $FAIL{'1-3 ORDERING OF DIHEDRALS'}=0
    }
    if($matchingpairs_W == $accounted1){
     $FAIL{'1-3 DIHEDRAL RELATIVE WEIGHTS'}=0
    }
    if($matchingpairs_A == $accounted1){
     $FAIL{'1-3 DIHEDRAL ANGLE VALUES'}=0
    }
    # check that all impropers are assigned about all CA atoms
    if($model eq "AA" && $AMINO_PRESENT){
     my $impCAfound=0;
     my $impCApossible=0;
     my $impOMEfound=0;
     my $impOMEpossible=0;
     my $impSCfound=0;
     my $impSCpossible=0;
     for(my $I=1;$I<=$finalres;$I++){
      if(exists $revData{"$I-CA"}){
       #check improper about CA  (CB-CA-C-N)
       if(exists $revData{"$I-CB"}){
        $impCApossible++;
        my $string;
        if($revData{"$I-CB"} < $revData{"$I-N"}){
         $string=sprintf("%i-%i-%i-%i",$revData{"$I-CB"} ,$revData{"$I-CA"} ,$revData{"$I-C"} ,$revData{"$I-N"});
        }else{
         $string=sprintf("%i-%i-%i-%i",$revData{"$I-N"} ,$revData{"$I-C"} ,$revData{"$I-CA"} ,$revData{"$I-CB"});
        }
        if($dihedral_array2{$string}){
         $impCAfound++;
        }else{
         $fail_log .= failed_message("Improper about CA atom not found: expected dihedral formed by atoms $string");
        }
        # check for expected side-chain impropers
        if($GRODATA[$revData{"$I-CA"}][1] !~  m/^TYR|^PHE|^TRP/){
         if(exists $revData{"$I-OG1"} && exists $revData{"$I-CG2"}){
          $impSCpossible++;
          my $string;
          if($revData{"$I-CA"} < $revData{"$I-CG2"}){
           $string=sprintf("%i-%i-%i-%i",$revData{"$I-CA"} ,$revData{"$I-CB"} ,$revData{"$I-OG1"} ,$revData{"$I-CG2"});
          }else{
           $string=sprintf("%i-%i-%i-%i",$revData{"$I-CG1"} ,$revData{"$I-OG1"} ,$revData{"$I-CB"} ,$revData{"$I-CA"});
          }
          if($dihedral_array2{$string}){
           $impSCfound++;
          }else{
           $fail_log .= failed_message("Sidechain Improper not found: expected dihedral formed by atoms $string");
          }
         }
         if(exists $revData{"$I-CG1"} && exists $revData{"$I-CG2"}){
          $impSCpossible++;
          my $string;
          if($revData{"$I-CA"} < $revData{"$I-CG2"}){
           $string=sprintf("%i-%i-%i-%i",$revData{"$I-CA"} ,$revData{"$I-CB"} ,$revData{"$I-CG1"} ,$revData{"$I-CG2"});
          }else{
           $string=sprintf("%i-%i-%i-%i",$revData{"$I-CG1"} ,$revData{"$I-CG1"} ,$revData{"$I-CB"} ,$revData{"$I-CA"});
          }
          if($dihedral_array2{$string}){
           $impSCfound++;
          }else{
           $fail_log .= failed_message("Sidechain Improper not found: expected dihedral formed by atoms $string");
          }
         }
         if(exists $revData{"$I-CG"} && exists $revData{"$I-CD1"} && exists $revData{"$I-CD2"}){
          $impSCpossible++;
          my $string;
          if($revData{"$I-CB"} < $revData{"$I-CD2"}){
           $string=sprintf("%i-%i-%i-%i",$revData{"$I-CB"} ,$revData{"$I-CG"} ,$revData{"$I-CD1"} ,$revData{"$I-CD2"});
          }else{
           $string=sprintf("%i-%i-%i-%i",$revData{"$I-CD2"} ,$revData{"$I-CD1"} ,$revData{"$I-CG"} ,$revData{"$I-CB"});
          }
          if($dihedral_array2{$string}){
           $impSCfound++;
          }else{
           $fail_log .= failed_message("Sidechain Improper not found: expected dihedral formed by atoms $string");
          }
         }
        }
       }
       my $nextres=$I+1;
       if(exists $revData{"$nextres-N"} && $CID[$revData{"$nextres-N"}] == $CID[$revData{"$I-CA"}]){
        $impOMEpossible++;
        #they are adjacent, and in the same chain, check improper about omega (O-CA-C-N+)
	my $string;
        if($revData{"$I-O"} < $revData{"$nextres-N"}){
         $string=sprintf("%i-%i-%i-%i",$revData{"$I-O"} ,$revData{"$I-CA"} ,$revData{"$I-C"} ,$revData{"$nextres-N"});
        }else{
         $string=sprintf("%i-%i-%i-%i",$revData{"$nextres-N"} ,$revData{"$I-C"} ,$revData{"$I-CA"} ,$revData{"$I-O"});
        }
        if($dihedral_array2{$string}){
         $impOMEfound++;
        }else{
         $fail_log .= failed_message("Improper about peptide bond not found: expected dihedral formed by atoms $string");
        }
       }
      }
     }
     if($impCAfound == $impCApossible && $impCApossible != 0){
      $FAIL{'CA IMPROPERS EXIST'}=0;
     }else{
      $fail_log .= failed_message("Only found $impCAfound improper dihedrals about CA atoms, out of an expected $impCApossible");
     }
     if($impOMEfound == $impOMEpossible){
      $FAIL{'OMEGA IMPROPERS EXIST'}=0;
     }else{
      $fail_log .= failed_message("Only found $impOMEfound improper omega dihedrals, out of an expected $impOMEpossible");
     }
     if($impSCfound == $impSCpossible){
      $FAIL{'SIDECHAIN IMPROPERS EXIST'}=0;
     }else{
      $fail_log .= failed_message("Only found $impSCfound sidechain improper dihedrals, out of an expected $impSCpossible");
     }
    }else{
     $FAIL{'CA IMPROPERS EXIST'}=-1;
     $FAIL{'OMEGA IMPROPERS EXIST'}=-1;
     $FAIL{'SIDECHAIN IMPROPERS EXIST'}=-1;
    }
   }
  } 
  
  if(exists $A[1]){
   # check values for contact energy
   if($A[1] eq "pairs"){
    $FOUND{'pairs'}++;
   # reset all the values because we can analyze multiple settings, and we want to make sure we always start at 0 and with arrays cleared.
    $CONTENERGY=0;
    my $FAIL_STACK=0;
    my $FAIL_NONSTACK=0;
    my $LONGCONT=0;
    my $CONTACT_W_CA=0;
    my $ContactDist=0;
    my $GaussianContactWidth=0;
    my $GaussianEXVOL=0;
    my $NOTSHORTSEQ=0;
    $#A = -1;
    $LINE=<TOP>;
    chomp($LINE);
    @A=split(/ /,$LINE);
    my $W;
    my $Cdist;
    my $CALCD;
    until($A[0] eq "["){
     $PAIRS[$NCONTACTS][0]=$A[0];
     $PAIRS[$NCONTACTS][1]=$A[1];
     $NCONTACTS++;

     unless($CID[$A[0]] == $CID[$A[1]] && $MOLTYPE[$A[0]] eq "AMINO" &&  abs($resindex[$A[0]]-$resindex[$A[1]]) <4 ){
	$NOTSHORTSEQ++;
     }

     if($CID[$A[0]] == $CID[$A[1]] && $MOLTYPE[$A[0]] eq "AMINO" && $MOLTYPE[$A[1]] eq "AMINO" &&  abs($resindex[$A[0]]-$resindex[$A[1]]) ==4 ){
	$FAIL{'CONTACTS PROTEIN i-j=4'}=0;
     }elsif($CID[$A[0]] == $CID[$A[1]] && $MOLTYPE[$A[0]] eq "NUCLEIC" && $MOLTYPE[$A[1]] eq "NUCLEIC" &&  abs($resindex[$A[0]]-$resindex[$A[1]]) ==1 ){
        $FAIL{'CONTACTS NUCLEIC i-j=1'}=0;
     }

     # determine the epsilon of the contact
     if($A[4] == 0){
      $fail_log .= failed_message("A divide by zero was encountered during testing. This typically means the top file is incomplete");
      $FAILED++; 
      last;
     }
     # the order of these if statements is important.
     if($gaussian eq "yes"){
      $W=$A[3];
      $Cdist=$A[4];
      $CALCD=(($XT[$A[0]]-$XT[$A[1]])**2+($YT[$A[0]]-$YT[$A[1]])**2+($ZT[$A[0]]-$ZT[$A[1]])**2)**(0.5);
      if(abs($Cdist-$CALCD) < 100.0/($PRECISION*1.0) ){
       $ContactDist++;
      }else{
       $fail_log .= failed_message("A contact appears to be the wrong distance.  From the .gro file, we found r=$CALCD, and from the .top r=$Cdist.\n\t$LINE");
      }
      # check width of gaussian
      my $sigmagaussian=$A[5];
      my $sigmagaussianCALC=-1;
      if($model eq "CA"){
       $sigmagaussianCALC=0.05;
      }elsif($model eq "AA"){
       $sigmagaussianCALC=$A[4]/sqrt(50.0*log(2.0));
      }
      if(abs($sigmagaussian-$sigmagaussianCALC) < 100.0/($PRECISION*1.0) ){
       $GaussianContactWidth++;
      }else{
       $fail_log .= failed_message("A gaussian contact appears to have the wrong width.  From the .top file, we found sigma=$sigmagaussian, but based on the native distance, we expect sigma=$sigmagaussianCALC.\n\t$LINE");
      }
      if(abs($rep_s12-$A[6]) < 100.0/($PRECISION*1.0) ){
       $GaussianEXVOL++;
      }else{
       $fail_log .= failed_message("A gaussian contact appears to have the wrong excluded volume.  From the .top file, we found a=$A[6], but expect a=$rep_s12.\n\t$LINE");
      }
     }elsif($model eq "CA"){
      $W=5.0**5.0/6.0**6.0*($A[3]**6.0)/($A[4]**5.0);
      $Cdist=(6*$A[4]/(5*$A[3]))**(1.0/2.0);
      $CALCD=(($XT[$A[0]]-$XT[$A[1]])**2+($YT[$A[0]]-$YT[$A[1]])**2+($ZT[$A[0]]-$ZT[$A[1]])**2)**(0.5);
      if(abs($Cdist-$CALCD) < 100.0/($PRECISION*1.0) ){
       $ContactDist++;
      }else{
       $fail_log .= failed_message("A contact appears to be the wrong distance.  From the .gro file, we found r=$CALCD, and from the .top r=$Cdist.\n\t$LINE");
      }
     }elsif($model eq "AA"){
      $W=($A[3]*$A[3])/(4*$A[4]);
      $Cdist=(2.0*$A[4]/($A[3]))**(1.0/6.0);
      $CALCD=(($XT[$A[0]]-$XT[$A[1]])**2+($YT[$A[0]]-$YT[$A[1]])**2+($ZT[$A[0]]-$ZT[$A[1]])**2)**(0.5);
      if(abs($Cdist-$CALCD) < 100.0/($PRECISION*1.0)){
       $ContactDist++;
      }else{
       $fail_log .= failed_message("A contact appears to be the wrong distance.  From the .gro file, we found r=$CALCD, and from the .top r=$Cdist.\n\t$LINE");
      }
     }else{
      smogcheck_error("unrecognized model.");
     }
     # so long as the contacts are not with ligands, then we add the sum
     if($model eq "CA"){
      $CONTENERGY+=$W;
      if($W > $MINTHR*$epsilonCAC and $W < $MAXTHR*$epsilonCAC){
       $CONTACT_W_CA++;
      }else{
       $fail_log .= failed_message("EpsilonC values\n\tValue: Target\n\t$W $epsilonCAC\n\tline:\n\t$LINE");
      }
     }elsif($model eq "AA"){
      $Cdist = int(($Cdist * $PRECISION)/10.0)/($PRECISION*10.0);
      if($Cdist <= $CONTD/10.0){
       $LONGCONT++;
      }else{
       $fail_log .= failed_message("long contact. distance $Cdist nm.\n\t$LINE");
     }
      ## so long as the contacts are not with ligands, then we add the sum
      if($MOLTYPE[$A[0]] ne "LIGAND" and $MOLTYPE[$A[1]] ne "LIGAND"){
       $CONTENERGY+=$W;
      }
      if($MOLTYPE[$A[0]] eq "NUCLEIC" and $MOLTYPE[$A[1]] eq "NUCLEIC" and $ATOMTYPE[$A[0]] ne "BACKBONE" and  $ATOMTYPE[$A[1]] ne "BACKBONE" and $ATOMNAME[$A[0]] ne "C1\*" and $ATOMNAME[$A[1]] ne "C1\*" and abs($RESNUM[$A[0]]-$RESNUM[$A[1]]) == 1 and $CID[$A[0]] == $CID[$A[1]]){
       # if we haven't assigned a value to stacking interactions, then let's save it
       # if we have saved it, check to see that this value is the same as the previous ones.
       if($stackingE == 0 ){
        $stackingE=$W;
       }elsif(abs($stackingE - $W) > 10.0/($PRECISION*1.0) ){
        $FAIL_STACK++;
        $fail_log .= failed_message("stacking energies: $stackingE  $W $A[0] $A[1]");
        }
      }else{
      # it is not a stacking contact.  Do the same checks for non-stacking interactions
       if($NonstackingE == 0 ){
        $NonstackingE=$W;
       }elsif(abs($NonstackingE - $W) > 10.0/($PRECISION*1.0) ){
        $FAIL_NONSTACK++;
        $fail_log .= failed_message("non-stacking contacts: $NonstackingE $W\n\tline:\n\t$LINE");
       }
      }
     }else{
      smogcheck_error("unrecognized model.");
     }
     # truncate the epsilon, for comparison purposes later.
     $W=int(($W * $PRECISION))/($PRECISION*1.0);
     # check to see if the contact is nucleic acids, adjacent residues and not backbone atoms.  These should be rescaled by a factor of 1/3
     # read the next line
     $#A = -1;
     $LINE=<TOP>;
     chomp($LINE);
     last unless defined $LINE;
     @A=split(/ /,$LINE);
    }
    if($NOTSHORTSEQ == $NCONTACTS){
     $FAIL{'CONTACTS PROTEIN i-j!<4'}=0;
    }
    if($ContactDist == $NCONTACTS){
     $FAIL{'CONTACT DISTANCES'}=0;
    }
    if($gaussian eq "yes"){
     if($GaussianContactWidth == $NCONTACTS){
      $FAIL{'GAUSSIAN CONTACT WIDTHS'}=0;
     }
     if($GaussianEXVOL == $NCONTACTS){
      $FAIL{'GAUSSIAN CONTACT EXCLUDED VOLUME'}=0;
     }
    }else{
      $FAIL{'GAUSSIAN CONTACT EXCLUDED VOLUME'}=-1;
      $FAIL{'GAUSSIAN CONTACT WIDTHS'}=-1;
    }
    if($model eq "AA"){
     if($LONGCONT == $NCONTACTS){
      $FAIL{'LONG CONTACTS'}=0;
     }
     if($NUCLEIC_PRESENT){
      if($FAIL_NONSTACK == 0 and $NonstackingE != 0){
       $FAIL{'NON-STACKING CONTACT WEIGHTS'}=0;	
      }
      if($FAIL_STACK == 0 and $stackingE != 0 ){
       $FAIL{'STACKING CONTACT WEIGHTS'}=0;	
      }
     }else{
       $FAIL{'STACKING CONTACT WEIGHTS'}=-1;	
      if($FAIL_NONSTACK == 0 and $NonstackingE != 0 ){
       $FAIL{'NON-STACKING CONTACT WEIGHTS'}=0;	
      }
     } 
     $FAIL{'CA CONTACT WEIGHTS'}=-1;	
    }elsif($model eq "CA"){
     if($NCONTACTS == $CONTACT_W_CA){
       $FAIL{'CA CONTACT WEIGHTS'}=0;	
     }
     $FAIL{'LONG CONTACTS'}=-1;
     $FAIL{'STACKING CONTACT WEIGHTS'}=-1;	
     $FAIL{'NON-STACKING CONTACT WEIGHTS'}=-1;	
    }elsif($model eq "AA" and !$NUCLEIC_PRESENT){
     $FAIL{'STACKING CONTACT WEIGHTS'}=-1;	
     $FAIL{'NON-STACKING CONTACT WEIGHTS'}=-1;	
    }else{
     smogcheck_error("unrecognized model.");
    }
   }
  } 
  if(exists $A[1]){ 
   if($A[1] eq "exclusions"){
    $FOUND{'exclusions'}++;
    $#A = -1;
    $LINE=<TOP>;
    @A=split(/ /,$LINE);
    my $NEXCL=0;
    my $NEXCLUSIONS=0;
    until($A[0] eq "["){
     if($PAIRS[$NEXCL][0] != $A[0] || $PAIRS[$NEXCL][1] != $A[1]){
      $NEXCLUSIONS++;
      $fail_log .= failed_message("mis-match between pairs and exclusions (pair $NEXCL)\n\tpair: $PAIRS[$NEXCL][0] $PAIRS[$NEXCL][1]\n\texcl: $A[0] $A[1]");
     }
     $NEXCL++;
     # read the next line
     $#A = -1;
     $LINE=<TOP>;
     last unless defined $LINE;
     @A=split(/ /,$LINE);
    }
    if($NEXCL == $NCONTACTS){
     $FAIL{'NUMBER OF EXCLUSIONS'}=0;
    }
   }
  }
  if(exists $A[1]){
   if($A[1] eq "system"){
    $FOUND{'system'}++;
    $LINE=<TOP>;
    chomp($LINE);
    @A=split(/ /,$LINE);
    if($A[0] eq "Macromolecule"){
     $FAIL{'NAME'}=0;
    }else{
     $fail_log .= failed_message("Default system name is ($A[0]) non-standard");
    }
   }
  }

  if(exists $A[1]){
   if($A[1] eq "molecules"){
    $FOUND{'molecules'}++;
    $LINE=<TOP>;
    chomp($LINE);
    @A=split(/ /,$LINE);
    if($A[0] eq "Macromolecule"){
     $FAIL{'NAME'}=0;
     if($A[1] == 1){
      $FAIL{'1 MOLECULE'}=0;
     }else{
      $fail_log .= failed_message("wrong number of molecules");
     }
    }
   }
  }
 }

 # check the dihedrals...
 my $NRIGID=0;
 my $NOMEGA=0;
 my $NRIGIDC=0;
 my $NOMEGAC=0;
 my $NPBB=0;
 my $NPBBC=0;
 my $NPSC=0;
 my $NPSCC=0;
 my $NNBB=0;
 my $NNBBC=0;
 my $NNSC=0;
 my $NNSCC=0;
 my $NLIG=0;
 my $NLIGC=0;
 my $PBBvalue=0;	
 my $PSCvalue=0;	
 my $NABBvalue=0;	
 my $NASCvalue=0;
 my $NUM_NONZERO=0;
 my $LIGdvalue=0;



 for(my $i=0;$i<$NUMATOMS+1;$i++){
  for(my $j=0;$j<=$DISP_MAX;$j++){
   if(exists $EDrig_T[$i][$j]){
    $NUM_NONZERO++;	
    if( ($ATOMNAME[$i] eq "C"  && $ATOMNAME[$i+$j] eq "N") || (  $ATOMNAME[$i] eq "N"  && $ATOMNAME[$i+$j] eq "C"   ) ||
        ($ATOMNAME[$i] eq "C"  && $ATOMNAME[$i+$j] eq "O3*") || (  $ATOMNAME[$i] eq "O3*"  && $ATOMNAME[$i+$j] eq "C"   )    ){
     $NRIGID++;
     if( abs($EDrig_T[$i][$j]-$omegaEps) > $TOLERANCE ){
      $fail_log .= failed_message("weird omega rigid...\n\t$i $j $EDrig_T[$i][$j]\n\t$ATOMNAME[$i] $ATOMNAME[$i+$j]\n\t$RESNUM[$i] $RESNUM[$i+$j]");
     }else{
     $NRIGIDC++;
     }
    }else{
     $NOMEGA++;
     if(abs($EDrig_T[$i][$j]-$ringEps) > $TOLERANCE ){
      $fail_log .= failed_message("weird ring dihedral...\n\t$i $j $EDrig_T[$i][$j]\n\t$ATOMNAME[$i] $ATOMNAME[$i+$j]\n\t$RESNUM[$i] $RESNUM[$i+$j]");
     }else{
     $NOMEGAC++;
     }
    }
   }
 
   if(exists $ED_T[$i][$j]){
    $ED_T[$i][$j]= int(($ED_T[$i][$j] * $PRECISION))/($PRECISION*1.0) ;
    if($MOLTYPE[$i] eq "AMINO"){
     if($ATOMTYPE[$i] eq "BACKBONE" or  $ATOMTYPE[$i+$j] eq "BACKBONE"){
      $NPBB++;
#      $DIH_TYPE[$i][$j]="AMINOBB";
      if($PBBvalue !=$ED_T[$i][$j] && $PBBvalue !=0){
       $fail_log .= failed_message("protein backbone dihedral $i $j\n\t$PBBvalue is before\n\t$ED_T[$i][$j] is the bad one...");
      }else{
       $NPBBC++;
      }
      $PBBvalue=$ED_T[$i][$j];
     }else{
      $NPSC++;
#      $DIH_TYPE[$i][$j]="AMINOSC";
      if($PSCvalue !=$ED_T[$i][$j] && $PSCvalue !=0){
       $fail_log .= failed_message("protein sidechain dihedral $i $j\n\t$PSCvalue is before\n\t$ED_T[$i][$j] is the bad one...");
      }else{
       $NPSCC++;
      }
     $PSCvalue=$ED_T[$i][$j];
     }
    }elsif($MOLTYPE[$i] eq "NUCLEIC"){
     if($ATOMTYPE[$i] eq "BACKBONE" or  $ATOMTYPE[$i+$j] eq "BACKBONE"){
#      $DIH_TYPE[$i][$j]="NUCLEICBB";
      $NNBB++;     
      if($NABBvalue !=$ED_T[$i][$j] && $NABBvalue != 0 ){
       $fail_log .= failed_message("nucleic backbone dihedral $i $j\n\t$NABBvalue is before\n\t$ED_T[$i][$j] is the bad one...");
      }else{
       $NNBBC++;     
      }
      $NABBvalue=$ED_T[$i][$j];
     }else{
      $NNSC++;     
#      $DIH_TYPE[$i][$j]="NUCLEICSC";
      if($NASCvalue !=$ED_T[$i][$j] && $NASCvalue !=0){
       $fail_log .= failed_message("nucleic sidechain dihedral $i $j\n\t$NASCvalue is before\n\t$ED_T[$i][$j] is the bad one...");
      }else{
       $NNSCC++;     
      }
      $NASCvalue=$ED_T[$i][$j];
     }
    }elsif($MOLTYPE[$i] eq "LIGAND"){
#     $DIH_TYPE[$i][$j]="LIGAND";
     $NLIG++;
     if($LIGdvalue !=$ED_T[$i][$j] && $LIGdvalue != 0 ){
      $fail_log .= failed_message("backbone atom $i $j\n\t$LIGdvalue is before\n\t$ED_T[$i][$j] is the bad one...");
     }else{
      $NLIGC++;
     }
     $LIGdvalue=$ED_T[$i][$j];
    }
   }
  }
 }
 if($NRIGID >0){
  if($NRIGID == $NRIGIDC){
   $FAIL{'STRENGTHS OF RIGID DIHEDRALS'}=0;
  }
 }elsif(! $AMINO_PRESENT){
   $FAIL{'STRENGTHS OF RIGID DIHEDRALS'}=-1;
 }
 if($NOMEGA>0){
  if($NOMEGA == $NOMEGAC){
   $FAIL{'STRENGTHS OF OMEGA DIHEDRALS'}=0;
  }
 }elsif(! $AMINO_PRESENT){
   $FAIL{'STRENGTHS OF OMEGA DIHEDRALS'}=-1;
 }
 if($NPBB>0){
  if($NPBB == $NPBBC){
   $FAIL{'STRENGTHS OF PROTEIN BB DIHEDRALS'}=0;
  }
 }elsif(! $AMINO_PRESENT){
   $FAIL{'STRENGTHS OF PROTEIN BB DIHEDRALS'}=-1;
 }
 if($NPSC>0){
  if($NPSC == $NPSCC){
   $FAIL{'STRENGTHS OF PROTEIN SC DIHEDRALS'}=0;
  }
 }elsif(! $AMINO_PRESENT){
   $FAIL{'STRENGTHS OF PROTEIN SC DIHEDRALS'}=-1;
 }
 if($NNBB>0){
  if($NNBB == $NNBBC){
   $FAIL{'STRENGTHS OF NUCLEIC BB DIHEDRALS'}=0;
  }
 }elsif(! $NUCLEIC_PRESENT){
   $FAIL{'STRENGTHS OF NUCLEIC BB DIHEDRALS'}=-1;
 }

 if($NNSC>0){
  if($NNSC == $NNSCC){
   $FAIL{'STRENGTHS OF NUCLEIC SC DIHEDRALS'}=0;
  }
 }elsif(! $NUCLEIC_PRESENT){
   $FAIL{'STRENGTHS OF NUCLEIC SC DIHEDRALS'}=-1;
 }
 if($NLIG>0){
  if($NLIG == $NLIGC){
   $FAIL{'STRENGTHS OF LIGAND DIHEDRALS'}=0;
  }
 }elsif(! $LIGAND_PRESENT){
   $FAIL{'STRENGTHS OF LIGAND DIHEDRALS'}=-1;
 }

 if($model eq "AA"){
  if($NonstackingE !=0 && $stackingE !=0){
   my $CR=$NonstackingE/$stackingE;
   if($CR < $MAXTHR and  $CR > $MINTHR){
    $FAIL{'STACK-NONSTACK RATIO'}=0;
   }else{
    $fail_log .= failed_message("NonStacking-stacking ratio issue: \n  Expected: 1, Actual: $CR");
   }
  }else{
   $FAIL{'STACK-NONSTACK RATIO'}=-1;
  }
 
  if($AMINO_PRESENT){
   my $ratio=$PBBvalue/$PSCvalue;
   if($ratio < $MAXTHR*$R_P_BB_SC   and $ratio > $MINTHR*$R_P_BB_SC ){
    $FAIL{'PROTEIN BB/SC RATIO'}=0;
   }else{
    $fail_log .= failed_message("Protein BB-SC Ratio issue: \n  Expected: $R_P_BB_SC, Actual: $ratio");
   }
   if($restypecount{"AMINO"} <5){
    $FAIL{'CONTACTS PROTEIN i-j=4'}=-1;
   }
  }else{
    $FAIL{'PROTEIN BB/SC RATIO'}=-1;
    $FAIL{'CONTACTS PROTEIN i-j=4'}=-1;
  }
  if($NUCLEIC_PRESENT){
   my $ratio=$NASCvalue/$NABBvalue;
   if($ratio < $MAXTHR*$R_N_SC_BB   and $ratio > $MINTHR*$R_N_SC_BB ){
    $FAIL{'NUCLEIC SC/BB RATIO'}=0;
   }else{
    $fail_log .= failed_message("Nucleic SC-BB Ratio issue:\n\tExpected: $R_N_SC_BB, Actual: $ratio");
   }
  }else{
    $FAIL{'NUCLEIC SC/BB RATIO'}=-1;
  }

  if($AMINO_PRESENT && $NUCLEIC_PRESENT){
   my $RR=$PBBvalue/$NABBvalue;
   my $RR_TARGET=$PRO_DIH/$NA_DIH;
   if($RR < $MAXTHR*$RR_TARGET and $RR > $MINTHR*$RR_TARGET){
    $FAIL{'AMINO/NUCLEIC DIHEDRAL RATIO'}=0;
   }else{
    $fail_log .= failed_message("FAIL: BB dihedral values protein: $PBBvalue nucleic acid: $NABBvalue\n\tTarget ratio: $RR_TARGET\n\tActual ratio: $RR");
   }
  }else{
    $FAIL{'AMINO/NUCLEIC DIHEDRAL RATIO'}=-1;
  }
  if($AMINO_PRESENT && $LIGAND_PRESENT){
   my $RR=$PBBvalue/$LIGdvalue;
   my $RR_TARGET=$PRO_DIH/$LIGAND_DIH;
   if($RR < $MAXTHR*$RR_TARGET and $RR > $MINTHR*$RR_TARGET){
    $FAIL{'AMINO/LIGAND DIHEDRAL RATIO'}=0;
   }else{
    $fail_log .= failed_message("protein: $PBBvalue Ligand: $LIGdvalue\n\tTarget ratio: $RR_TARGET\n\tActual ratio: $RR");
   }
  }else{
    $FAIL{'AMINO/LIGAND DIHEDRAL RATIO'}=-1;
  }
  if($LIGAND_PRESENT && $NUCLEIC_PRESENT){
   my $RR=$LIGdvalue/$NABBvalue;
   my $RR_TARGET=$LIGAND_DIH/$NA_DIH;
   if($RR < $MAXTHR*$RR_TARGET and $RR > $MINTHR*$RR_TARGET){
    $FAIL{'NUCLEIC/LIGAND DIHEDRAL RATIO'}=0;
   }else{
    $fail_log .= failed_message("ligand: $LIGdvalue nucleic acid: $NABBvalue\n\tTarget ratio: $RR_TARGET\n\tActual ratio: $RR");
   }
  }else{
    $FAIL{'NUCLEIC/LIGAND DIHEDRAL RATIO'}=-1;
  }
  ## check if the range of dihedrals is reasonable  

  my $D_R=$DIH_MAX/ $DIH_MIN;
  if($D_R > $MAXTHR*4*$R_P_BB_SC  ){
   print "WARNING!!!: range of dihedrals is large\n";
  }
  my $CD_ratio;
  if($DENERGY > 0){
   $CD_ratio=$CONTENERGY/$DENERGY;
   $FAIL{'NONZERO DIHEDRAL ENERGY'}=0;
   if($MAXTHR*$R_CD > $CD_ratio and $MINTHR*$R_CD < $CD_ratio){
   $FAIL{'CONTACT/DIHEDRAL RATIO'}=0;
   }else{
    $fail_log .=failed_message("Contact/Dihedral ratio is off. Expected $R_CD, found $CD_ratio.");
   }
  }
 }else{
    $FAIL{'STRENGTHS OF RIGID DIHEDRALS'}=-1;
    $FAIL{'STRENGTHS OF OMEGA DIHEDRALS'}=-1;
    $FAIL{'STRENGTHS OF PROTEIN BB DIHEDRALS'}=-1;
    $FAIL{'STACK-NONSTACK RATIO'}=-1;
    $FAIL{'PROTEIN BB/SC RATIO'}=-1;
    $FAIL{'NUCLEIC SC/BB RATIO'}=-1;
    $FAIL{'AMINO/NUCLEIC DIHEDRAL RATIO'}=-1;
    $FAIL{'AMINO/LIGAND DIHEDRAL RATIO'}=-1;
    $FAIL{'NUCLEIC/LIGAND DIHEDRAL RATIO'}=-1;
   $FAIL{'NONZERO DIHEDRAL ENERGY'}=-1;
   $FAIL{'CONTACT/DIHEDRAL RATIO'}=-1;
 } 

 unless($NUCLEIC_PRESENT){
  $FAIL{'CONTACTS NUCLEIC i-j=1'}=-1;
 }
 unless($AMINO_PRESENT){
  $FAIL{'CONTACTS PROTEIN i-j=4'}=-1;
 }
 my $NFIELDS=@FIELDS;
 my $NFIELDC=0;
 foreach(@FIELDS){
  my $FF=$_;
  if($FOUND{"$FF"} == 1){
   $NFIELDC++;
  }elsif($FOUND{"$FF"} == 0){
   $fail_log .= failed_message("Directive [ $FF ] not found in top file.  This either means SMOG did not complete, or there was a problem reading the file.  All subsequent output will be meaningless.");
  }else{
   smogcheck_error("Serious problem understanding .top file.  A directive may be duplicated.");
  }
 }
 if($NFIELDS == $NFIELDC){
  $FAIL{'TOP FIELDS FOUND'}=0;
 }
}


sub checkvalues
{

 ## DONE READING IN THE FILE.  TIME TO CHECK AND SEE IF ALL THE RATIOS ARE CORRECT
# print "number of atoms = $NUMATOMS\n";
# print "number of atoms(excluding ligands and ions) = $NUMATOMS_LIGAND\n";
# print "Dihedral energy = $DENERGY\n";
# print "Contact energy = $CONTENERGY\n";
# print "max dihedral = $DIH_MAX\n";
# print "min dihedral = $DIH_MIN\n";
# print "generated angles, dihedrals, impropers\n";
# print "$theta_gen_N $phi_gen_N $improper_gen_N\n";
 if($model eq "CA"){
  if($theta_gen_N > 0 and $phi_gen_N > 0 ){
   $FAIL{'GENERATION OF ANGLES/DIHEDRALS'}=0;
  }else{
   smogcheck_error("Unable to generate angles ($theta_gen_N), or dihedrals ($phi_gen_N)...");
  }
 }elsif($model eq "AA"){
  if($theta_gen_N > 0 and $phi_gen_N > 0 and $improper_gen_N > 0){
   $FAIL{'GENERATION OF ANGLES/DIHEDRALS'}=0;

  }else{
    smogcheck_error("Unable to generate angles ($theta_gen_N), dihedrals ($phi_gen_N), or impropers ($improper_gen_N)...");
  }
 }else{
  smogcheck_error("unrecognized model. Quitting...");
 }
 ## check the energy per dihedral and where the dihedral is SC/BB NA/AMINO
 if($DISP_MAX == 0){
  internal_error("DISP_MAX");
 }

 if($model eq "AA"){
  if(open(CFILE,"$PDB.contacts")){
   $FAIL{'OPEN CONTACT FILE'}=0;
  }
 }elsif($model eq "CA"){
  if(open(CFILE,"$PDB.contacts.CG")){
   $FAIL{'OPEN CONTACT FILE'}=0;
  }
 }


 my $NUMBER_OF_CONTACTS_SHADOW=0;
 while(<CFILE>){
  $NUMBER_OF_CONTACTS_SHADOW++;
 }
  my $NRD=$NCONTACTS+$bondtype6;
 if($NUMBER_OF_CONTACTS_SHADOW == $NRD){
  $FAIL{'NCONTACTS'}=0;

 }else{
  $fail_log .= failed_message("Same number of contacts not found in contact file and top file!!!! FAIL\n\t$NUMBER_OF_CONTACTS_SHADOW contacts were found in the contact file.\n\t$NRD contacts were found in the top file.");
 }
 my $E_TOTAL=$DENERGY+$CONTENERGY;
 my $CTHRESH=$NUMATOMS*10.0/$PRECISION;
 if($model eq "AA"){ 
  if(abs($NUMATOMS_LIGAND-$E_TOTAL) < $CTHRESH){
   $FAIL{'TOTAL ENERGY'}=0;
  }else{
   $fail_log .= failed_message("Inconsistent total energy: Expected $NUMATOMS_LIGAND, found $E_TOTAL");
  }
 }else{
   $FAIL{'TOTAL ENERGY'}=-1;
 }

}

sub cleanoldfiles
{
 if(-e "$PDB.top"){
  `rm $PDB.top`;
 }
 if(-e "$PDB.gro"){
  `rm $PDB.gro`;
 }
 if(-e "$PDB.ndx"){
  `rm $PDB.ndx`;
 }
}

sub summary
{

 my ($FAILED,$printbuffer)=failsum(\%FAIL,\@FAILLIST);
 if($FAILED > 0){
 my $tmpstring = <<"EOT";
************************************************************* 
     $FAILED CHECKS FAILED FOR TEST $TESTNUM ($PDB)!!!
EOT
 $printbuffer = $tmpstring . $printbuffer;
 $printbuffer .= <<"EOT";
Note: Will save files with names FAILED/$PDB.fail$TESTNUM.X
*************************************************************
EOT

print $printbuffer;

  `cp share/PDB.files/$PDB.pdb $FAILDIR/$PDB.fail$TESTNUM.pdb`;
  open(FAILLOG,">$FAILDIR/$PDB.fail$TESTNUM.log") or smogcheck_error("unable to open log file for writing");
  print FAILLOG "$printbuffer\nSee possible additional messages below\n$fail_log";
  close(FAILLOG);
  foreach(@FILETYPES){
   if(-e "$PDB.$_"){
    `mv $PDB.$_ $FAILDIR/$PDB.fail$TESTNUM.$_`;
   }
   
   for (my $m=1;$m<=4;$m++){
    if(-e "$PDB.meta$m.$_"){
     `mv $PDB.meta$m.$_ $FAILDIR/$PDB.fail$TESTNUM.meta$m.$_`;
    }
   }
  }

  if(-d "temp.bifsif"){
   `mv temp.bifsif $FAILDIR/$PDB.fail$TESTNUM.bifsif`;
  }
   if(-d "temp.cont.bifsif"){
    `mv temp.cont.bifsif $FAILDIR/$PDB.fail$TESTNUM.cont.bifsif`;
   }
   
  $FAIL_SYSTEM++;
 }else{
  print "\n*************************************************************\n";
  print "                 CHECK $TESTNUM PASSED ($PDB)\n";
  print  "*************************************************************\n";
  foreach(@FILETYPES){
   if(-e "$PDB.$_"){
    `rm $PDB.$_`;
   }
   if(-d "temp.bifsif"){
   `rm -r temp.bifsif `;
  }
   if(-d "temp.cont.bifsif"){
    `rm -r temp.cont.bifsif`;
   }
 

   for (my $m=1;$m<=4;$m++){
    if(-e "$PDB.meta$m.$_"){
     `rm $PDB.meta$m.$_`;
    }
   }
  } 
 }
}

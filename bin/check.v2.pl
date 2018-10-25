use strict;
use warnings;
use smog_common;
use check_common;
# This is the main script that runs SMOG2 and then checks to see if the generated files are correct.
# This is intended to be a brute-force evaluation of everything that should appear. Since this is
# a testing script, it is not designed to be efficient, but to be thorough, and foolproof...

my $VERSION="2.2beta";
my $tmpstring = <<"EOS";

                    smog-check                                   

       smog-check is part of the SMOG 2 distribution, available at smog-server.org     

       This tool will check your installation of SMOG 2, to ensure 
		that a number of models are being constructed properly.

                       See the SMOG manual for usage guidelines.

            For questions regarding this script, contact info\@smog-server.org              

EOS

my $wide=88;

printdashed($wide);
printcenter($wide,$tmpstring);
printdashed($wide);

# check if we are simply rerunning a single test, a few tests, or performing all
my $RETEST=$#ARGV;
my $RETESTEND=-1;
if($RETEST == 0 || $RETEST == 1 ){
	my $RETESTT;
	if($ARGV[0] =~ /^\d+$/){
		# is an integer
		$RETESTT=$ARGV[0];
		$RETESTEND=$RETESTT;
	}else{
		# is not an integer.  flag error
		smogcheck_error("argument to smog-check can only be one, or two, integers. Found \"$ARGV[0]\"");
	}

	if($RETEST == 1 ){
		if($ARGV[1] =~ /^\d+$/){
			# is an integer
			$RETESTEND=$ARGV[1];
			print "\nWill run tests $ARGV[0] to $ARGV[1].\n\n";
		}else{
			# is not an integer.  flag error
			smogcheck_error("argument to smog-check can only be one, or two, integers. Found \"$ARGV[0]\"");
		}
		if($ARGV[1] < $ARGV[0]){
			smogcheck_error("Arguments must be first test, then last test. Last test number must be larger.");
		}
	}else{
		print "\nWill only run test $ARGV[0].\n\n";
	}
	$RETEST=$RETESTT;

}elsif($RETEST== -1){
	print "\nWill run all tests (default).\n\n";
}else{
	smogcheck_error("Too many arguments passed to smog-check");
}

&checkForModules;

# a number of global variables. This is a bit sloppy, since most of them do not need to be global.  Maybe later we'll convert some back to my declarations.
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
our $TEMPLATE_DIR_AA_MATCH=$ENV{'BIFSIF_AA_MATCH'};
# FAILLIST is a list of all the tests.
# If you are developing and testing your own forcefield, which may not need to conform to certain checks, then you may want to disable some tests by  removing the test name from this list. However, do so at your own risk.

our @FAILLIST = ('NAME','DEFAULTS, nbfunc','DEFAULTS, comb-rule','DEFAULTS, gen-pairs','1 MOLECULE','ATOMTYPES UNIQUE','ALPHANUMERIC ATOMTYPES','TOP FIELDS FOUND','TOP FIELDS RECOGNIZED','MASS', 'CHARGE','moleculetype=Macromolecule','nrexcl=3', 'PARTICLE', 'C6 VALUES', 'C12 VALUES', 'SUPPORTED BOND TYPES', 'OPEN GRO','GRO-TOP CONSISTENCY', 'BOND STRENGTHS', 'BOND LENGTHS','ANGLE TYPES', 'ANGLE WEIGHTS', 'ANGLE VALUES','DUPLICATE BONDS', 'DUPLICATE ANGLES', 'GENERATED ANGLE COUNT','GENERATED ANGLE IN TOP','ANGLES IN TOP GENERATED', 'IMPROPER WEIGHTS', 'CA IMPROPERS EXIST','OMEGA IMPROPERS EXIST','SIDECHAIN IMPROPERS EXIST','MATCH DIH WEIGHTS','MATCH DIH ANGLES','ALL POSSIBLE MATCHED DIHEDRALS PRESENT','CA DIHEDRAL WEIGHTS', 'DUPLICATE TYPE 1 DIHEDRALS','DUPLICATE TYPE 2 DIHEDRALS','DUPLICATE TYPE 3 DIHEDRALS','1-3 DIHEDRAL PAIRS','3-1 DIHEDRAL PAIRS','1-3 ORDERING OF DIHEDRALS','1-3 DIHEDRAL RELATIVE WEIGHTS','STRENGTHS OF RIGID DIHEDRALS','STRENGTHS OF OMEGA DIHEDRALS','STRENGTHS OF PROTEIN BB DIHEDRALS','STRENGTHS OF PROTEIN SC DIHEDRALS','STRENGTHS OF NUCLEIC BB DIHEDRALS','STRENGTHS OF NUCLEIC SC DIHEDRALS','STRENGTHS OF LIGAND DIHEDRALS','STACK-NONSTACK RATIO','PROTEIN BB/SC RATIO','NUCLEIC SC/BB RATIO','AMINO/NUCLEIC DIHEDRAL RATIO','AMINO/LIGAND DIHEDRAL RATIO','NUCLEIC/LIGAND DIHEDRAL RATIO','NONZERO DIHEDRAL ENERGY','CONTACT/DIHEDRAL RATIO','1-3 DIHEDRAL ANGLE VALUES','DIHEDRAL IN TOP GENERATED','GENERATED DIHEDRAL IN TOP','STACKING CONTACT WEIGHTS','NON-STACKING CONTACT WEIGHTS','LONG CONTACTS', 'CA CONTACT WEIGHTS', 'CONTACT DISTANCES','GAUSSIAN CONTACT WIDTHS','GAUSSIAN CONTACT EXCLUDED VOLUME','CONTACTS NUCLEIC i-j=1','CONTACTS PROTEIN i-j=4','CONTACTS PROTEIN i-j!<4','SCM CONTACT COMPARISON','NUMBER OF EXCLUSIONS', 'BOX DIMENSIONS','GENERATION OF ANGLES/DIHEDRALS','OPEN CONTACT FILE','NCONTACTS','TOTAL ENERGY','TYPE6 ATOMS','UNINITIALIZED VARIABLES','CLASSIFYING DIHEDRALS','NON-ZERO EXIT','ATOM FIELDS','ATOM CHARGES','FREE PAIRS APPEAR IN CONTACTS','EXTRAS ADDED','NONZERO LIGAND DIHEDRAL VALUE');
# default location of test PDBs
our $PDB_DIR="share/PDB.files";
# where should data from failed tests be written
our $FAILDIR="FAILED";
# are we testing files with free interactions?
our $free;
# will add free-specific hashes, here
our @FILETYPES=("top","gro","ndx","settings","contacts","output","contacts.SCM", "contacts.CG");

# bunch of global vars.  A bit sloppy.  Many could be local.
our ($AMINO_PRESENT,$angleEps,@atombondedtype,%atombondedtypes,%atombondedtypes2,@ATOMNAME,@ATOMTYPE,$BBRAD,%BBTYPE,$bondEps,$bondMG,$bondtype6,%C12NB,%C6NB,$chargeAT,%chargeNB,%CHECKED,@CID,$CONTD,$CONTENERGY,$CONTR,$CONTTYPE,$default,%defcharge,$defname,$DENERGY,$dihmatch,$DIH_MAX,$DIH_MIN,$DISP_MAX,@EDrig_T,@ED_T,$epsilon,$epsilonCAC,$epsilonCAD,%FAIL,$FAILED,$fail_log,@FIELDS,$gaussian,@GRODATA,$impEps,$improper_gen_N,$ION_PRESENT,$LIGAND_DIH,$LIGAND_PRESENT,%massNB,%matchangle_val,%matchangle_weight,%matchbond_val,%matchbond_weight,%matchdihedral_val,%matchdihedral_weight,$model,@MOLTYPE,%MOLTYPEBYRES,$NA_DIH,$NCONTACTS,$NUCLEIC_PRESENT,$NUMATOMS,$NUMATOMS_LIGAND,$omegaEps,$PDB,$phi_gen_N,$PRO_DIH,$R_CD,$rep_s12,@RESNUM,%restypecount,$ringEps,$R_N_SC_BB,$R_P_BB_SC,$sigma,$sigmaCA,$theta_gen_N,%TYPE,$type6count,$usermap,@XT,@YT,@ZT);

$DISP_MAX=0;
# before testing anything, make sure this version of smog-check is compatible with the version of smog2
my $smogversion=`$EXEC_NAME -v | tail -n 1`;
chomp($smogversion);
$smogversion=~s/Version //g;
$smogversion=~/^\s+|\s+$/;
if($VERSION ne $smogversion){
 smogcheck_error("Incompatible versions of SMOG ($smogversion) and SMOG-CHECK ($VERSION)");	
}

my %supported_directives = ( 'defaults' => '1','atomtypes' => '1','moleculetype' => '1','nonbond_params' => '0','atoms' => '1','bonds' => '1','angles' => '1','dihedrals' => '1','pairs' => '1','exclusions' => '1','system' => '1','molecules' => '1');

# list the bonds that are free in the free-templates
my %free_bond_defs=('TRP-CG-CD1' =>'1');
# list the angles that are free in the free-templates
my %free_angle_defs=('GLN-CB-CG-CD' =>'1');
# list the dihedrals that are free in the free-templates
my %free_dihedrals_defs=('TYR-CB-CG' =>'1',
			 'TYR-CG-CD1' =>'1',
			 'TYR-CD1-CE1' =>'1',
			 );
# list the residue pairs that free in the free-templates
my %free_pair_defs=('ASN-MET' =>'1',
	   	    'ASN-ASN' =>'1',
	   	    'MET-MET' =>'1'
		   );

unless(-d $BIFSIF_AA && -d $BIFSIF_CA && -d $TEMPLATE_DIR_AA && -d $TEMPLATE_DIR_AA_STATIC && -d $TEMPLATE_DIR_CA ){
 smogcheck_error("Can\'t find the template directories. Something is wrong with the configurations of this script.\nYour intallation of SMOG2 may be ok, but we can\'t tell\nGiving up...");
}

print "environment variables read\n";
print "EXEC_NAME $EXEC_NAME\n";

unless( -e $SCM){
 smogcheck_error("Can\'t find Shadow!");
}

my %numfield = ( 'default' => '2', 'default-userC' => '2', 'default-gaussian' => '2', 'default-gaussian-userC' => '2','cutoff' => '19', 'shadow' => '20',  'shadow-free' => '20', 'shadow-gaussian' => '20', 'cutoff-gaussian' => '19' , 'shadow-match' => '4');

my $FAIL_SYSTEM=0;

%defcharge = ('GLY-N' => "0.3", 'GLY-C' => "0.2", 'GLY-O' => "-0.5");
my $NUMTESTED=0;
my $SETTINGS_FILE=<STDIN>;
chomp($SETTINGS_FILE);
open(PARMS,"$SETTINGS_FILE") or internal_error("The settings file is missing...");
my $TESTNUM=0;


&readbackbonetypes;
&readresiduetypes;
&runalltests;

#*************************END OF MAIN ROUTINE**********************


#*****************************SUBROUTINES**************************

sub readbackbonetypes
{
 ## read in the backbone atom types.  Remember, CA and C1* can be involved in sidechain dihedrals
 my %files = ( 'aminoacids' => 'AMINO','nucleicacids'=>'NUCLEIC','ligands'=>'LIGAND');
 foreach my $f(keys %files){
  open(FF,"share/backboneatoms/$f") or internal_error("can not open share/backboneatoms/$f");
  while(<FF>){
   my $LINE=$_;
   chomp($LINE);
   $LINE =~ s/\s+$//;
   if(defined $TYPE{$LINE}){
    smogcheck_error("$LINE given more than once in share/residues files");
   }
   $BBTYPE{"$files{$f}-$LINE"}= "BACKBONE";
  }
  close(FF);
 }
}

sub readresiduetypes
{
 ## LOAD INFORMATION ABOUT WHAT TYPES OF RESIDUES ARE RECOGNIZED BY SMOG2
 my %files = ( 'aminoacids' => 'AMINO','nucleicacids'=>'NUCLEIC','ligands'=>'LIGAND','ions'=>'ION');
 foreach my $f(keys %files){
  open(FF,"share/residues/$f") or internal_error("can not open share/residues/$f");
  while(<FF>){
   my $LINE=$_;
   chomp($LINE);
   $LINE =~ s/\s+$//;
   if(defined $TYPE{$LINE}){
    smogcheck_error("$LINE given more than once in share/residues files");
   }
   $TYPE{$LINE}= $files{$f};
  }
  close(FF);
 }
}

sub runalltests{
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
  if($RETEST>0 && ($RETEST > $TESTNUM || $RETESTEND < $TESTNUM)){
   next;
  }
  $NUMTESTED++;
 
  print "\n*************************************************************\n";
  print "                 STARTING TEST $TESTNUM ($PDB)\n";
  print "*************************************************************\n";

  if(! -e "$PDB_DIR/$PDB.pdb"){
   smogcheck_error("Unable to find PDB file $PDB_DIR/$PDB.pdb for testing.");
  }

  &resetvars; 

  $model=$A[1];
  my $contactmodel=$A[2];
 
  ($default,$gaussian,$usermap,$free)=setmodelflags($model,$contactmodel,\%numfield,\@A);
 
  # clean up the tracking for the next test
  %FAIL=resettests(\%FAIL,\@FAILLIST);

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
 my $nottested=alltested(\%CHECKED,\%FAIL);
 if($nottested eq ""){
 print <<EOT;
*************************************************************
                      PASSED ALL TESTS  !!!
*************************************************************
EOT
 exit(0);
}else{
  print <<EOT;
*************************************************************
$nottested
*************************************************************
EOT
 exit(1);
 }
}elsif($RETEST > 0){
if($RETESTEND != -1){
 print <<EOT;
*************************************************************
                 PASSED TESTS $RETEST to $RETESTEND  !!!
*************************************************************
EOT
  }
  exit(0);
 }
}

sub resetvars
{
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
 undef  %massNB;
 undef  %atombondedtypes;
 undef  %atombondedtypes2;
 undef  @atombondedtype;
 undef  %chargeNB;
 undef  %C6NB;
 undef  %C12NB;
 undef  %matchbond_val;
 undef  %matchbond_weight;
 undef  %matchangle_val;
 undef  %matchangle_weight;
 undef  %matchdihedral_val;
 undef  %matchdihedral_weight;
 undef  $chargeAT;
 undef  $bondEps;
 undef  $angleEps;
 undef  $dihmatch;
}

sub alltested
{
 my ($CH,$FA)=@_;
 %CHECKED=%{$CH}; 
 %FAIL=%{$FA};
# check to see if every possible test has been checked, at least one time.
 my $nottested="";
 foreach my $name(keys %FAIL){
  if(!exists $CHECKED{$name}){
   $nottested .= "$name\n";
  }
 }
 if($nottested ne ""){
  $nottested = "Not all possible tests have been checked.  Unchecked tests include:\n$nottested";
 }
 return $nottested;
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
   smogcheck_error("Unrecognized model when preparing default smog 2 flags.");
  }
 }else{
  if($model eq "CA"){
   $ARGS .= " -tCG temp.bifsif/  -t temp.cont.bifsif";
  }elsif($model eq "AA"){
   $ARGS .= " -t temp.bifsif/ ";
  }elsif($model eq "AA-match"){
   $ARGS .= " -t $TEMPLATE_DIR_AA_MATCH ";
  }else{
   smogcheck_error("Unrecognized model when preparing non-default smog 2 flags.");
  }
 }
 if($usermap eq "yes"){
   $ARGS .= " -c $PDB_DIR/$PDB.contacts ";
 }
# run smog2
 `$EXEC_NAME $ARGS &> $PDB.output`;
}

sub setmodelflags{
 my ($model,$contactmodel,$numfield,$A)=@_;
 my @A=@{$A};
 my %numfield=%{$numfield};
 my $NA=$#A;
 # default is that we are not testing free
 $free="no";
 # default is to not read a contact map
 $usermap="no";

 if($contactmodel =~ m/^default$/){
  $default="yes";
  $gaussian="no";
 }elsif($contactmodel =~ m/^default-gaussian$/){
  print "Will use gaussian contacts\n";
  $default="yes";
  $gaussian="yes";
 }elsif($contactmodel =~ m/^default-gaussian-userC$/){
  print "Will use gaussian contacts with user-provided distances\n";
  $default="yes";
  $gaussian="yes";
  $usermap="yes";
 }elsif($contactmodel =~ m/^default-userC$/){
  print "Will use default settings with user-provided contact and distances\n";
  $default="yes";
  $gaussian="no";
  $usermap="yes";
 }elsif($contactmodel =~ m/^cutoff$/){
  print "Will use cutoff contacts\n";
  $default="no";
  $gaussian="no";
 }elsif($contactmodel =~ m/^shadow$/ || $contactmodel =~ m/^shadow-match$/){
  print "Will use shadow contacts\n";
  $default="no";
  $gaussian="no";
 }elsif($contactmodel =~ m/^shadow-free$/){
  print "Will use shadow contacts\n";
  print "Checking use of \"free\" interactions\n";
  $default="no";
  $gaussian="no";
  $free="yes";
 }elsif($contactmodel =~ m/^shadow-gaussian$/ || $contactmodel =~ m/^cutoff-gaussian$/){
  print "Will use gaussian contacts\n";
  $default="no";
  $gaussian="yes";
 }else{
  smogcheck_error("Unknown contact option: \"$contactmodel\"");
 }
 if(!exists $numfield{$contactmodel}){
  internal_error("model $contactmodel in all.pdbs is not recognized");
 }
 if($numfield{$contactmodel} != $NA){
  internal_error("all.pdbs has wrong number of entries for model $contactmodel. Expected $numfield{contactmodel}, found $NA");
 }
 if($usermap eq "yes"){
  unless(-e "$PDB_DIR/$PDB.contacts"){
   print "Unable to find PDB file $PDB_DIR/$PDB.contacts for testing.  Skipping this test\n\n";
   $FAIL_SYSTEM++;
   next;
  }
 }
 if($model =~ m/CA/){
  print "Testing CA model\n";
 }elsif($model =~ m/AA/){
  print "Testing AA model\n";
 }else{
  smogcheck_error("Model name $model, not understood. Only CA and AA models are supported by the test script.");
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
  if($CONTTYPE =~ m/^shadow$/ || $CONTTYPE =~ m/^shadow-free$/ || $CONTTYPE =~ m/^shadow-match$/ || $CONTTYPE =~ m/^shadow-gaussian$/ ){
   print "Will generate and use a shadow map\n";
   $CONTD=$A[$ARG];
   $ARG++;
   $CONTR=$A[$ARG];
   $ARG++;
   $BBRAD=0.5;
  }elsif($CONTTYPE =~ m/^cutoff$/ || $CONTTYPE =~ m/^cutoff-gaussian$/){
   print "Will generate and use a cutoff map\n";
   $CONTD=$A[$ARG];
   $ARG++;
   $CONTR=0.0;
   $BBRAD=0.0;
  }else{
   smogcheck_error("Contact scheme $CONTTYPE is not supported. Is there a typo in $PDB_DIR/$PDB.pdb?");
  }
  if($CONTTYPE =~ m/match/){
   # if we are using a "match" template, then read corresponding expected values
   $R_CD=1.0; # using a default value with the match templates
  }else{
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
   $massNB{'NB_2'}=$A[$ARG];
    $ARG++;
   $chargeNB{'NB_2'}=$A[$ARG];
    $ARG++;
   $C6NB{'NB_2'}=$A[$ARG];
    $ARG++;
   $C12NB{'NB_2'}=$A[$ARG];
    $ARG++;
   $chargeAT=$A[$ARG];
  }
 }
 if($model eq "CA"){
  $bondEps=20000;
  $angleEps=40;
 }elsif($model eq "AA"){
  $bondEps=10000;
  $angleEps=80;
 }elsif($model eq "AA-match"){
  undef $bondEps;
  undef $angleEps;
  $dihmatch=0;
 }else{
  smogcheck_error("Model name $model, not understood. Only CA and AA models are supported by the test script.");
 }
 $bondMG=200;
 $ringEps=40;
 $omegaEps=10;
 $impEps=10;
 return ($default,$gaussian,$usermap,$free);
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

 }elsif($model eq "AA-match"){
  my $SHADOWARGS="-g $PDB.gro -t $PDB.top -ch $PDB.ndx -o $PDB.contacts.SCM -m shadow -c $CONTD -s $CONTR -br $BBRAD -bif $TEMPLATE_DIR_AA_MATCH/*.bif";
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
 }elsif($usermap eq "yes"){
  $FAIL{'SCM CONTACT COMPARISON'}=-1;
 }else{
  $fail_log .= failed_message("smog-check could not generate identical SCM map. Check $PDB.contacts and $PDB.contacts.SCM");
 }
 if(! -e "$PDB.contacts.SCM"){
  smogcheck_error("Unable to re-generate contact map");
 } 
}

sub smogchecker
{
 &cleanoldfiles;
 &preparesettings;
 print "Running SMOG 2\n";
 &runsmog; 

 ($FAIL{'NON-ZERO EXIT'},$FAIL{'UNINITIALIZED VARIABLES'})=checkoutput("$PDB.output");

 if($FAIL{'UNINITIALIZED VARIABLES'} == 1){
  $fail_log .= failed_message("SMOG 2 encountered uninitialized variables.");
 }
 if($PDB =~ m/BOND$/){
  # BOND in name means disable check
  $FAIL{'GENERATED DIHEDRAL IN TOP'}=-1; 
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
 my $templateAA="AA-whitford09";
 my $templateCA="CA-clementi00";
my $string = <<"EOT";
Here were the settings used for this test
$PDB.pdb
$PDB.top
$PDB.gro
$PDB.ndx
EOT

 if($model =~ m/AA/){
  $string .= "All-Atom\n";
 }else{
  $string .= "Coarse-Grained\n";
 }	
 
 if($model =~ m/match/){
  $string .= "atom, bond and angle matching will be applied\n";
 }else{
$string .= <<"EOT";
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
}
 open(READSET,">$PDB.settings") or internal_error("can not open settings file");
 print READSET "$string";
 close(READSET);
 if($model eq "CA"){
  $sigmaCA=$sigmaCA/10.0;
  $rep_s12=$sigmaCA**12;
  if($default eq "yes"){
   $defname="NB_1";
  }else{
   $defname="Y";
  }
  $C12NB{$defname}=$rep_s12;
  $C6NB{$defname}=0;
  $massNB{$defname}=1.0;
  $chargeNB{$defname}=0.0;
  $sigmaCA=$sigmaCA*10.0;
 }elsif($model eq "AA"){
  $sigma=$sigma/10;
  $rep_s12=$sigma**12*$epsilon;
   $defname="NB_1";
  $C12NB{$defname}=$rep_s12;
  $C6NB{$defname}=0;
  $massNB{$defname}=1.0;
  $chargeNB{$defname}=0.0;
  $sigma=$sigma*10;
 }elsif($model eq "AA-match"){
  my $atomtypefile="$TEMPLATE_DIR_AA_MATCH/atomtypes";
  print "reading atom bonded type expected values from:\n\t$atomtypefile\n";
  open(ATF,"$atomtypefile") or smogcheck_error("unable to open $atomtypefile");
  while(<ATF>){
   my $LINE=$_;
   my ($data,$comment)=checkcomment($LINE);
   my @A=split(/ /,$data);
   if($#A != 2){
    smogcheck_error("wrong number of fields if atomtype file. Offending line:\n\t$data\n");
   }
   my $ttype="$A[0]-$A[1]";
   if(exists $atombondedtypes{$ttype}){
    smogcheck_error("$ttype defined more than once in atomtype file. Offending line:\n\t$data\n");
   }
   $atombondedtypes{$ttype}=$A[2];
   $atombondedtypes2{$A[2]}=0;
  }
  close(ATF);
  my $compare="$TEMPLATE_DIR_AA_MATCH/comparelist";
  print "will using \"matching\" template. Target values will be read from\n\t$compare\n"; 
  open(MATCH,"$compare") or smogcheck_error("unable to open $compare");
  while(<MATCH>){
   my $LINE=$_;
   my ($data,$comment)=checkcomment($LINE);
   my @A=split(/ /,$data);
   if($A[0] eq "atom"){
    if($#A != 4){
     smogcheck_error("wrong number of fields if compare file. Offending line:\n\t$data\n");
    }
    if(exists $massNB{$A[1]}){
     smogcheck_error("$A[1] defined more than once in compare file. Offending line:\n\t$data\n");
    }
    $massNB{$A[1]}=$A[2];
    $chargeNB{$A[1]}=$A[3];
    $C12NB{$A[1]}=$A[4];
    $C6NB{$A[1]}=0;
   }elsif($A[0] eq "bond"){
    if($#A != 4){
     smogcheck_error("wrong number of fields if compare file. Offending line:\n\t$data\n");
    }
    my $bondname="$A[1]-$A[2]";
    if(!exists $atombondedtypes2{$A[1]}){
     smogcheck_error("bond $bondname defined, but bonded type $A[1] not defined. Offending line:\n\t$data\n");
    }
    if(!exists $atombondedtypes2{$A[2]}){
     smogcheck_error("bond $bondname defined, but bonded type $A[2] not defined. Offending line:\n\t$data\n");
    }
    if(exists $matchbond_val{$bondname}){
     smogcheck_error("bond $bondname defined more than once in compare file. Offending line:\n\t$data\n");
    }
    $matchbond_val{$bondname}=$A[3];
    $matchbond_weight{$bondname}=$A[4];
   }elsif($A[0] eq "angle"){
    if($#A != 5){
     smogcheck_error("wrong number of fields if compare file. Offending line:\n\t$data\n");
    }
    my $anglename="$A[1]-$A[2]-$A[3]";
    if(exists $matchangle_val{$anglename}){
     smogcheck_error("angle $anglename defined more than once in compare file. Offending line:\n\t$data\n");
    }
    $matchangle_val{$anglename}=$A[4];
    $matchangle_weight{$anglename}=$A[5];
   }elsif($A[0] eq "dihedral"){
    if($#A != 6){
     smogcheck_error("wrong number of fields if compare file. Offending line:\n\t$data\n");
    }
    my $dihname="$A[1]-$A[2]-$A[3]-$A[4]";
    if(exists $matchdihedral_val{$dihname}){
     smogcheck_error("dihedral $dihname defined more than once in compare file. Offending line:\n\t$data\n");
    }
    $matchdihedral_val{$dihname}=$A[5];
    $matchdihedral_weight{$dihname}=$A[6];
   }else{
    smogcheck_error("Unsupported field in $compare\n\t $A[0]");
   }
  }
  close(MATCH);
 }else{
  smogcheck_error("unknown model type.");
 }
 # make some special entries to handle extras
 if($model eq "AA" && $default ne "yes"){
  $C12NB{"extratype"}=7;
  $C6NB{"extratype"}=2;
  $massNB{"extratype"}=2.1;
  $chargeNB{"extratype"}=-3.0;
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
  `sed "s/EPS_CONT/$epsilonCAC/g;s/EPS_DIH/$epsilonCAD/g;s/EPS_dih3/$epsilonCAD3/g" $TEMPLATE_DIR_CA/$templateCA.sif > temp.bifsif/tmp.sif`;
  `sed "s/PARM_C12/$rep_s12/g;s/EPS_CONT/$epsilonCAC/g" $TEMPLATE_DIR_CA/*.nb > temp.bifsif/tmp.nb`;
  `sed "s/EPS_CONT/$epsilonCAC/g;s/EPS_DIH/$epsilonCAD/g;s/EPS_dih3/$epsilonCAD3/g" $TEMPLATE_DIR_CA/$templateCA.b > temp.bifsif/tmp.b`;
  `cp $TEMPLATE_DIR_CA/$templateCA.bif temp.bifsif/tmp.bif`;

  `cp $TEMPLATE_DIR_AA_STATIC/$templateAA.bif temp.cont.bifsif/tmp.cont.bif`;
  `cp $TEMPLATE_DIR_AA_STATIC/$templateAA.nb temp.cont.bifsif/tmp.cont.nb`;
  `cp $TEMPLATE_DIR_AA_STATIC/$templateAA.b temp.cont.bifsif/tmp.cont.b`;
  if($CONTTYPE eq "shadow"){
   `sed "s/CUTDIST/$CONTD/g;s/SCM_R/$CONTR/g;s/SCM_BR/$BBRAD/g" $TEMPLATE_DIR_AA_STATIC/$templateAA.shadow.sif > temp.cont.bifsif/tmp.cont.sif`;
  }elsif($CONTTYPE eq "cutoff"){
   `sed "s/CUTDIST/$CONTD/g" $TEMPLATE_DIR_AA_STATIC/$templateAA.cutoff.sif > temp.cont.bifsif/tmp.cont.sif`;
  }
 CheckTemplatesCreated("temp.cont.bifsif","tmp.cont");
 } 

 if($model eq "AA" && $default ne "yes"){
  `mkdir temp.bifsif`;
  my $PARM_P_BB=$PRO_DIH;
  my $PARM_P_SC=$PRO_DIH/$R_P_BB_SC;
  my $PARM_N_BB=$NA_DIH;
  my $PARM_N_SC=$NA_DIH*$R_N_SC_BB;
  if($CONTTYPE eq "shadow"){
   `sed "s/PARM_C_D/$R_CD/g;s/PARM_P_BB/$PARM_P_BB/g;s/PARM_P_SC/$PARM_P_SC/g;s/PARM_N_BB/$PARM_N_BB/g;s/PARM_N_SC/$PARM_N_SC/g;s/CUTDIST/$CONTD/g;s/SCM_R/$CONTR/g;s/SCM_BR/$BBRAD/g" $TEMPLATE_DIR_AA/$templateAA.shadow.sif > temp.bifsif/tmp.sif`;
  }elsif($CONTTYPE eq "shadow-free"){
   `sed "s/PARM_C_D/$R_CD/g;s/PARM_P_BB/$PARM_P_BB/g;s/PARM_P_SC/$PARM_P_SC/g;s/PARM_N_BB/$PARM_N_BB/g;s/PARM_N_SC/$PARM_N_SC/g;s/CUTDIST/$CONTD/g;s/SCM_R/$CONTR/g;s/SCM_BR/$BBRAD/g" $TEMPLATE_DIR_AA/$templateAA.shadow.free.sif > temp.bifsif/tmp.sif`;
  }elsif($CONTTYPE eq "cutoff"){
   `sed "s/PARM_C_D/$R_CD/g;s/PARM_P_BB/$PARM_P_BB/g;s/PARM_P_SC/$PARM_P_SC/g;s/PARM_N_BB/$PARM_N_BB/g;s/PARM_N_SC/$PARM_N_SC/g;s/CUTDIST/$CONTD/g" $TEMPLATE_DIR_AA/$templateAA.cutoff.sif > temp.bifsif/tmp.sif`;
  }
  `sed "s/PARM_MASS/$massNB{'NB_2'}/g;s/PARM_chargeNB/$chargeNB{'NB_2'}/g;s/PARM_C6_2/$C6NB{'NB_2'}/g;s/PARM_C12_2/$C12NB{'NB_2'}/g;s/PARM_C12/$C12NB{$defname}/g" $TEMPLATE_DIR_AA/$templateAA.nb > temp.bifsif/tmp.nb`;

  if($CONTTYPE eq "shadow-free"){
   `sed "s/PARM_MASS/$massNB{'NB_2'}/g;s/PARM_chargeNB/$chargeNB{'NB_2'}/g;s/PARM_C6_2/$C6NB{'NB_2'}/g;s/PARM_C12_2/$C12NB{'NB_2'}/g;s/PARM_C12/$C12NB{$defname}/g" $TEMPLATE_DIR_AA/$templateAA.free.nb > temp.bifsif/tmp.nb`;
   `cp $TEMPLATE_DIR_AA/$templateAA.free.bif temp.bifsif/tmp.bif`;
   `cp $TEMPLATE_DIR_AA/$templateAA.free.b temp.bifsif/tmp.b`;
  }else{
   `sed "s/PARM_MASS/$massNB{'NB_2'}/g;s/PARM_chargeNB/$chargeNB{'NB_2'}/g;s/PARM_C6_2/$C6NB{'NB_2'}/g;s/PARM_C12_2/$C12NB{'NB_2'}/g;s/PARM_C12/$C12NB{$defname}/g" $TEMPLATE_DIR_AA/$templateAA.nb > temp.bifsif/tmp.nb`;
   `cp $TEMPLATE_DIR_AA/$templateAA.bif temp.bifsif/tmp.bif`;
   `cp $TEMPLATE_DIR_AA/$templateAA.b temp.bifsif/tmp.b`;
  }
  `cp $TEMPLATE_DIR_AA/extras temp.bifsif/extras`;
  CheckTemplatesCreated("temp.bifsif","tmp");
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
 my $topNlines=0;
 my @topdata;
 while(<TOP>){
  my $LINE=$_;
  chomp($LINE);
  my ($A,$B)=checkcomment($LINE);
  if($A eq ""){
   next;
  }
  $topdata[$topNlines]=$A;
  $topNlines++;
 }
 close(TOP);
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
 my %seen;
 my %seendihedrals;
 foreach(keys %supported_directives){
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
 for(my $N=0;$N<$topNlines;$N++){
  my $LINE=$topdata[$N];
  if(substr($LINE,0,1) eq "["){
   @A=split(/ /,$LINE);
   if(exists $A[0] && $A[0] eq "[" && exists $A[1]){
    $FOUND{$A[1]}++;
   }
  }
 }
 my $LN=0;
 while($LN<$topNlines){
  my $LINE=$topdata[$LN];$LN++;
  @A=split(/ /,$LINE);
  if(exists $A[1]){
   if($A[1] eq "defaults"){
    $LINE=$topdata[$LN];$LN++;
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
    $#A = -1;
    $LINE=$topdata[$LN];$LN++;
    @A=split(/ /,$LINE);
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
      smogcheck_error("atomtype name $A[0] appears more than once.");
     }
     if($A[0] =~ /^[a-zA-Z0-9_]+$/){
      $acceptablenames++;
     }else{
      my $T=$A[0];
      smogcheck_error("Only letters, numbers and _ can appear in atomtype names. atomtype $T found.");
     }
     if(defined $massNB{$A[0]} && $A[1] > $MINTHR*$massNB{$A[0]} && $A[1] < $MAXTHR*$massNB{$A[0]}){
      $mass1++;
     }
     if(defined $chargeNB{$A[0]} && $A[2] >= $MINTHR*$chargeNB{$A[0]} && $A[2] <= $MAXTHR*$chargeNB{$A[0]} && $chargeNB{$A[0]} >= 0){
      $charge1++;
     }elsif(defined $chargeNB{$A[0]} && $A[2] <= $MINTHR*$chargeNB{$A[0]} && $A[2] >= $MAXTHR*$chargeNB{$A[0]} && $chargeNB{$A[0]} < 0){
      $charge1++;
     }
     if($A[3] eq "A"){
      $particle1++;
     }
     if(defined $C6NB{$A[0]} && $A[4] >= $MINTHR*$C6NB{$A[0]} && $A[4] <= $MAXTHR*$C6NB{$A[0]}){
      $c61++
     }
     if(defined $C12NB{$A[0]} && $A[5] > $MINTHR*$C12NB{$A[0]} && $A[5] < $MAXTHR*$C12NB{$A[0]}){
      $excl1++;
     }
     $#A = -1;
     $LINE=$topdata[$LN];$LN++;
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
    if($numtypes == $acceptablenames and $acceptablenames !=0){
     $FAIL{'ALPHANUMERIC ATOMTYPES'}=0;
    }
    if($model eq "AA" && $default ne "yes"){
     if(exists $seen{"extratype"}){
      $FAIL{'EXTRAS ADDED'}=0;
     }
    }else{
     $FAIL{'EXTRAS ADDED'}=-1;
    }
   }
  } 
  if(exists $A[1]){
   # check the excluded volume is consistent with the settings.
   if($A[1] eq "moleculetype"){
    $LINE=$topdata[$LN];$LN++;
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
    $NUMATOMS=0;
    my $fieldnum=0;
    my $atomcharge=0;
    $NUMATOMS_LIGAND=0;
    $#A = -1;
    $LINE=$topdata[$LN];$LN++;
    @A=split(/ /,$LINE);
    until($A[0] eq "["){
    # atom name
     $ATOMNAME[$A[0]]=$A[4];
     # if we are matching hetergeneous parameters, we need to store the smog-internal bonded types
     if($model eq "AA-match"){
      if(exists $atombondedtypes{"$A[3]-$A[4]"}){
       $atombondedtype[$A[0]]=$atombondedtypes{"$A[3]-$A[4]"};
      }else{
       smogcheck_error('Test broken. Not all atom types in the system have a reference bonded type provided.');
      }
     }
     for(my $J=0;$J<5;$J++){
      $A[$J] =~ s/^\s+|\s+$//g;
     }
     for(my $J=0;$J<4;$J++){
      $GRODATA[$NUMATOMS][$J] =~ s/^\s+|\s+$//g;
     }
     if($A[0] != $GRODATA[$NUMATOMS][3]){
      $FAIL_GROTOP++;
     }
     if(exists $defcharge{"$A[3]-$A[4]"} && $#A==6){
      $fieldnum++;
      # check charge
      if($defcharge{"$A[3]-$A[4]"} == $A[6]){
       $atomcharge++;
      }else{
       $fail_log .= failed_message("atom has wrong charge\t$LINE");
      }
     }elsif(!exists $defcharge{"$A[3]-$A[4]"} && $#A==5){
      $fieldnum++;
      $atomcharge++;
     }elsif($default eq "yes" && $#A==5){
      $fieldnum++;
     }else{
      $fail_log .= failed_message("atom has wrong number of fields\t$LINE");
     }

     if($A[4] ne $GRODATA[$NUMATOMS][2]){
      $FAIL_GROTOP++;
     }
     # check if it is a backbone atom. This list does not include CA and C1* because this classification is only used for determining which bonds are backbone and which are sidechain
     my $atomt="$TYPE{$A[3]}-$A[4]";
     if(exists $BBTYPE{$atomt}){
      $ATOMTYPE[$A[0]]=$BBTYPE{$atomt};
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
     $LINE=$topdata[$LN];$LN++;
     @A=split(/ /,$LINE);
    }
    if($FAIL_GROTOP ==0){
     $FAIL{'GRO-TOP CONSISTENCY'}=0;
    }
    if($fieldnum == $NUMATOMS){
     $FAIL{'ATOM FIELDS'}=0;
    }
    if($atomcharge == $NUMATOMS){
     $FAIL{'ATOM CHARGES'}=0;
    }
    if($default eq "yes"){
     $FAIL{'ATOM CHARGES'}=-1;
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
    my $CORRECTBONDLENGTHS=0;
    for (my $I=1;$I<=$NUMATOMS;$I++){
       $NbondWatom[$I]=0;
    }
    $LINE=$topdata[$LN];$LN++;
    @A=split(/ /,$LINE);
    until($A[0] eq "["){
     $NBONDS++;
     if($A[2] == 1){
      $RECOGNIZEDBTYPES++;
      my $bweight;
      my $bval;
      if(defined  $bondEps){
       # there is a homogeneous value used
       $bweight=$bondEps;
      }else{
       # heterogeneous bonds need to be checked (obtained from compare file).
       my $bt1=$atombondedtype[$A[0]];
       my $bt2=$atombondedtype[$A[1]];
       if(exists $matchbond_weight{"$bt1-$bt2"}){
        # check for the expected values of the weight, if defined 
        $bweight=$matchbond_weight{"$bt1-$bt2"};
        $bval=$matchbond_val{"$bt1-$bt2"};
        if(abs($A[3]- $bval) > 10E-10){
         $fail_log .= failed_message("bond has incorrect length. Expected $bval. Found:\n\t$LINE");
        }else{
         $CORRECTBONDLENGTHS++;
        }	
       }else{
	# since one only needs to provide weights that are used, 
	# we verify here, as opposed to checking all possible combinations earlier
        smogcheck_error("Bonded types $bt1 $bt2 don\'t have a defined reference weight.")
       }
      }
      if(abs($A[4] - $bweight) > 10E-10){
       $fail_log .= failed_message("bond has incorrect weight. Expected $bweight. Found:\n\t$LINE");
      }else{
       $CORRECTBONDWEIGHTS++;
      }		
      ##check if bond has already appeared in the .top file
      if($A[0] < $A[1]){
       $string=sprintf("%i-%i", $A[0], $A[1]);
      }else{
       $string=sprintf("%i-%i", $A[1], $A[0]);
      }
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
     $LINE=$topdata[$LN];$LN++;
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
    if(defined  $bondEps){
     # not checking values
     $FAIL{'BOND LENGTHS'}=-1; 
    }elsif($CORRECTBONDLENGTHS == $NBONDS && $NBONDS !=0){
     $FAIL{'BOND LENGTHS'}=0;
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
        if($free eq "yes"){
	 # if the residue-atom-atom-atom pair matches something that we defined as free, then don't generate it.
	 my $RESTMP=$GRODATA[$theta1-1][1];
	 my $A1=$GRODATA[$theta1-1][2];
	 my $A2=$GRODATA[$theta2-1][2];
	 my $A3=$GRODATA[$theta3-1][2];
         if(exists $free_angle_defs{"$RESTMP-$A1-$A2-$A3"} || exists $free_angle_defs{"$RESTMP-$A3-$A2-$A1"} ){
          next;
         }
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
    my $CORRECTBONDANGLES=0;
    for (my $I=1;$I<=$NUMATOMS;$I++){
       $NangleWatom[$I]=0;
    }

    my %angle_array;
    my $string;
    $LINE=$topdata[$LN];$LN++;
    @A=split(/ /,$LINE);
    until($A[0] eq "["){
     if($A[3] == 1){
      $CORRECTAT++;
     }
     my $aweight;
     my $aval;
     if(defined  $angleEps){
      # there is a homogeneous value used
      $aweight=$angleEps;
     }else{
      # heterogeneous bonds need to be checked (obtained from compare file).
      my $at1=$atombondedtype[$A[0]];
      my $at2=$atombondedtype[$A[1]];
      my $at3=$atombondedtype[$A[2]];
      if(exists $matchangle_weight{"$at1-$at2-$at3"}){
       # check for the expected values of the weight, if defined 
       $aweight=$matchangle_weight{"$at1-$at2-$at3"};
       $aval=$matchangle_val{"$at1-$at2-$at3"};
       if(abs($A[4]- $aval) > 10E-10){
        $fail_log .= failed_message("bond has incorrect angle. Expected $aval. Found:\n\t$LINE");
       }else{
        $CORRECTBONDANGLES++;
       }	
      }else{
       # since one only needs to provide weights that are used, 
       # we verify here, as opposed to checking all possible combinations earlier
       smogcheck_error("Bonded types $at1 $at2 $at3 don\'t have a defined reference angle weight.")
      }
     }
     if(abs($A[5] - $aweight) > 10E-10){
      $fail_log .= failed_message("bond angle has incorrect weight. Expected $aweight. Found:\n\t$LINE");
     }else{
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
      my $A0=$A[0];
      my $A1=$A[1];
      my $A2=$A[2];
      $angles2[$Nangles][0]=$A0;
      $angles2[$Nangles][1]=$A1;
      $angles2[$Nangles][2]=$A2;
      # this organization is also strange, but it will make sense later...
      $angleWatom[$A0][$NangleWatom[$A0]]= $Nangles;
      $angleWatom[$A1][$NangleWatom[$A1]]= $Nangles;
      $angleWatom[$A2][$NangleWatom[$A2]]= $Nangles;
      $NangleWatom[$A0]++;
      $NangleWatom[$A1]++;
      $NangleWatom[$A2]++;
      $Nangles++;
     }else{
      ## bond has already been assigned.
      $doubleangle++;
     }
     $LINE=$topdata[$LN];$LN++;
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
     $FAIL{'GENERATED ANGLE COUNT'}=0;
    }else{
     $fail_log .= failed_message("The number of generated angles is inconsistent with the number of angles in the top file\n\tgenerated: $theta_gen_N, found: $Nangles");
     $FAIL{'GENERATED ANGLE COUNT'}=1;
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
     $FAIL{'GENERATED ANGLE IN TOP'}=0;
    }else{
     $FAIL{'GENERATED ANGLE IN TOP'}=1;
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
     $FAIL{'ANGLES IN TOP GENERATED'}=0;
    }else{
     $FAIL{'ANGLES IN TOP GENERATED'}=1;
    }
    if(defined  $angleEps){
     # not checking values
     $FAIL{'ANGLE VALUES'}=-1; 
    }elsif($CORRECTBONDANGLES == $Nangles && $Nangles !=0){
     $FAIL{'ANGLE VALUES'}=0;
    }
 
    # generate all possible dihedral angles based on bond angles
    undef %phi_gen_as;
    $phi_gen_N=0;
    $#phi_gen=-1;
    undef %improper_gen_as;
    $improper_gen_N=0;
    $#improper_gen=-1;
    my ($formed,$phi1,$phi2,$phi3,$phi4,$AIJ,$AIK,$A1,$A2,$A3,$B1,$B2,$B3);
    for(my $i=1;$i<=$NUMATOMS;$i++){
    # go through the atoms.  For each atom, check all of the angles it is involved in, and see if we can make an angle out of it.
     for(my $j=0;$j<$NangleWatom[$i];$j++){
      $AIJ=$angleWatom[$i][$j];
      $A1=$angles2[$AIJ][0];
      $A2=$angles2[$AIJ][1];
      $A3=$angles2[$AIJ][2];
      for(my $k=$j+1;$k<$NangleWatom[$i];$k++){
       if($j!=$k){
        $AIK=$angleWatom[$i][$k];
        $B1=$angles2[$AIK][0];
        $B2=$angles2[$AIK][1];
        $B3=$angles2[$AIK][2];
        # find any dihedral angle that can be made with these two angles
	($formed,$phi1,$phi2,$phi3,$phi4)=identifydih($A1,$A2,$A3,$B1,$B2,$B3);
        if($formed eq "proper" ){
         if($phi1 < $phi4){
          $string=sprintf("%i-%i-%i-%i", $phi1, $phi2, $phi3, $phi4);
         }else{
          $string=sprintf("%i-%i-%i-%i", $phi4, $phi3, $phi2, $phi1);
         }
         if($free eq "yes"){
	  # if the residue-atom-atom pair matches something that we defined as free, then don't generate it.
	  my $RESTMP=$GRODATA[$phi2-1][1];
	  my $A1=$GRODATA[$phi2-1][2];
	  my $A2=$GRODATA[$phi3-1][2];
          if(exists $free_dihedrals_defs{"$RESTMP-$A1-$A2"} || exists $free_dihedrals_defs{"$RESTMP-$A2-$A1"} ){
           next;
          }
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
    my $CORRECTDIHEDRALANGLES=0;
    my $CORRECTDIHEDRALWEIGHTS=0;
    $#A = -1;
    $#ED_T = -1;
    $#EDrig_T = -1;
    $LINE=$topdata[$LN];$LN++;
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
     # only going to check the value for matching if type 1
       my $dihweight;
       my $dihval;
       if(defined  $dihmatch){
        # heterogeneous bonds need to be checked (obtained from compare file).
        my $at1=$atombondedtype[$A[0]];
        my $at2=$atombondedtype[$A[1]];
        my $at3=$atombondedtype[$A[2]];
        my $at4=$atombondedtype[$A[3]];
        my $dname="$at1-$at2-$at3-$at4";
        $seendihedrals{$dname}=0;
        if(exists $matchdihedral_weight{"$dname"}){
         # check for the expected values of the weight, if defined 
         my $dweight=$matchdihedral_weight{"$dname"};
         my $dval=$matchdihedral_val{"$dname"};
         if(abs($A[5]- $dval) > 10E-10){
          $fail_log .= failed_message("dihedral has incorrect angle. Expected $dval. Found:\n\t$LINE");
         }else{
          $CORRECTDIHEDRALANGLES++;
         }	
         if(abs($A[6]- $dweight) > 10E-10){
          $fail_log .= failed_message("dihedral has incorrect weight. Expected $dweight. Found:\n\t$LINE");
         }else{
          $CORRECTDIHEDRALWEIGHTS++;
         }	
        }else{
         # since one only needs to provide weights that are used, 
         # we verify here, as opposed to checking all possible combinations earlier
         smogcheck_error("Bonded types $at1 $at2 $at3 $at4 don\'t have a defined reference dihedral angle weight.")
        }
       }
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
     $LINE=$topdata[$LN];$LN++;
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
     $FAIL{'DIHEDRAL IN TOP GENERATED'}=0;
    }else{
     $FAIL{'DIHEDRAL IN TOP GENERATED'}=1;
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
     $FAIL{'GENERATED DIHEDRAL IN TOP'}=0;
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
     $FAIL{'1-3 DIHEDRAL PAIRS'}=0;
    }
    if(defined  $dihmatch){
     if($CORRECTDIHEDRALANGLES == $accounted1){
      $FAIL{'MATCH DIH ANGLES'}=0;
     }
     if($CORRECTDIHEDRALWEIGHTS == $accounted1){
      $FAIL{'MATCH DIH WEIGHTS'}=0;
     }
    }else{
      $FAIL{'MATCH DIH WEIGHTS'}=-1;
      $FAIL{'MATCH DIH ANGLES'}=-1;

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
          }elsif($free eq "no"){
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
          }elsif($free eq "no"){
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
          }elsif($free eq "no"){
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
     if($free eq "yes"){
      $FAIL{'SIDECHAIN IMPROPERS EXIST'}=-1;
     }elsif($impSCfound == $impSCpossible){
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
    my $freepair=0;
    $#A = -1;
    $LINE=$topdata[$LN];$LN++;
    @A=split(/ /,$LINE);
    my $W;
    my $Cdist;
    my $CALCD;
    if($usermap eq "yes"){
     open(CMAP,"$PDB_DIR/$PDB.contacts") or internal_error("can not open $PDB_DIR/$PDB.contacts");
    }
    until($A[0] eq "["){
     $PAIRS[$NCONTACTS][0]=$A[0];
     $PAIRS[$NCONTACTS][1]=$A[1];
     $NCONTACTS++;
     my $R0=$GRODATA[$A[0]-1][1];
     my $R1=$GRODATA[$A[1]-1][1];
     if($free eq "yes" && (exists $free_pair_defs{"$R0-$R1"} || exists $free_pair_defs{"$R0-$R1"})){
      $freepair=1;
      $fail_log .= failed_message("Free contacts defined, but a contact between $R0 and $R1 was found in the contacts. Atoms $A[0] and $A[1]\n");
     }
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
      $CALCD=getdist(\*CMAP,$A[0],$A[1]);
      if(abs($Cdist-$CALCD) < 100.0/($PRECISION*1.0) ){
       $ContactDist++;
      }else{
       $fail_log .= failed_message("A contact appears to be the wrong distance.  From the .gro (or .contact) file, we found r=$CALCD, and from the .top r=$Cdist.\n\t$LINE");
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
      $CALCD=getdist(\*CMAP,$A[0],$A[1]);
      if(abs($Cdist-$CALCD) < 100.0/($PRECISION*1.0) ){
       $ContactDist++;
      }else{
       $fail_log .= failed_message("A contact appears to be the wrong distance.  From the .gro (or .contact) file, we found r=$CALCD, and from the .top r=$Cdist.\n\t$LINE");
      }
     }elsif($model eq "AA" || $model eq "AA-match"){
      $W=($A[3]*$A[3])/(4*$A[4]);
      $Cdist=(2.0*$A[4]/($A[3]))**(1.0/6.0);
      $CALCD=getdist(\*CMAP,$A[0],$A[1]);
      if(abs($Cdist-$CALCD) < 100.0/($PRECISION*1.0)){
       $ContactDist++;
      }else{
       $fail_log .= failed_message("A contact appears to be the wrong distance.  From the .gro (or .contact) file, we found r=$CALCD, and from the .top r=$Cdist.\n\t$LINE");
      }
     }else{
      smogcheck_error("Contact-model combination not recognized.");
     }
     # so long as the contacts are not with ligands, then we add the sum
     if($model eq "CA"){
      $CONTENERGY+=$W;
      if($W > $MINTHR*$epsilonCAC and $W < $MAXTHR*$epsilonCAC){
       $CONTACT_W_CA++;
      }else{
       $fail_log .= failed_message("EpsilonC values\n\tValue: Target\n\t$W $epsilonCAC\n\tline:\n\t$LINE");
      }
     }elsif($model eq "AA" || $model eq "AA-match" ){
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
      smogcheck_error("Model not recognized.");
     }
     # truncate the epsilon, for comparison purposes later.
     $W=int(($W * $PRECISION))/($PRECISION*1.0);
     # check to see if the contact is nucleic acids, adjacent residues and not backbone atoms.  These should be rescaled by a factor of 1/3
     # read the next line
     $#A = -1;
     $LINE=$topdata[$LN];$LN++;
     @A=split(/ /,$LINE);
    }
    if($NOTSHORTSEQ == $NCONTACTS){
     $FAIL{'CONTACTS PROTEIN i-j!<4'}=0;
    }elsif($usermap eq "yes"){
     $FAIL{'CONTACTS PROTEIN i-j!<4'}=-1;
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
    if($model eq "AA" || $model eq "AA-match"){
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
    }elsif(($model eq "AA" || $model eq "AA-match") and !$NUCLEIC_PRESENT){
     $FAIL{'STACKING CONTACT WEIGHTS'}=-1;	
     $FAIL{'NON-STACKING CONTACT WEIGHTS'}=-1;	
    }else{
     smogcheck_error("Unrecognized model when checking contacts.");
    }
    if($freepair ==0){
     $FAIL{'FREE PAIRS APPEAR IN CONTACTS'}=0;	
    }else{
     $FAIL{'FREE PAIRS APPEAR IN CONTACTS'}=1;	
    }
   }
  } 
  if(exists $A[1]){ 
   if($A[1] eq "exclusions"){
    $#A = -1;
    $LINE=$topdata[$LN];$LN++;
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
     $LINE=$topdata[$LN];$LN++;
     @A=split(/ /,$LINE);
    }
    if($NEXCL == $NCONTACTS){
     $FAIL{'NUMBER OF EXCLUSIONS'}=0;
    }
   }
  }
  if(exists $A[1]){
   if($A[1] eq "system"){
    $LINE=$topdata[$LN];$LN++;
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
    $LINE=$topdata[$LN];$LN++;
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
 if(defined $dihmatch){
  my $c1=0; 
  my $c2=0; 
  foreach my $T1(keys %atombondedtypes2){
   foreach my $T2(keys %atombondedtypes2){
    foreach my $T3(keys %atombondedtypes2){
     foreach my $T4(keys %atombondedtypes2){
      my $dihetmp="$T1-$T2-$T2-$T3";
      $c1++;
      if(! exists $seendihedrals{$dihetmp}){;
       $fail_log .= failed_message("Did not find dihedral with bonded types $dihetmp");
      }else{
      $c2++;
      }
     }
    }
   }
  }
  if($c1==$c2){
   $FAIL{'ALL POSSIBLE MATCHED DIHEDRALS PRESENT'}=0;
  }
 }else{
   $FAIL{'ALL POSSIBLE MATCHED DIHEDRALS PRESENT'}=-1;
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
     # make sure that, if the dihedral is in a ligand (ANP, GNP), it must not involve the backbone
     if($MOLTYPE[$i] eq "LIGAND" && ($ATOMTYPE[$i] eq "BACKBONE" or  $ATOMTYPE[$i+$j] eq "BACKBONE")){
      $fail_log .= failed_message("Rigid dihedral assigned to ligand backbone. script expects these to be flexible. \n\t$i $j $EDrig_T[$i][$j]\n\t$ATOMNAME[$i] $ATOMNAME[$i+$j]\n\t$RESNUM[$i] $RESNUM[$i+$j]");
      next; # by going to next, this will automatically flag errors with regards to number of rigids
     }
     if(abs($EDrig_T[$i][$j]-$ringEps) > $TOLERANCE ){
      $fail_log .= failed_message("weird ring dihedral...\n\t$i $j $EDrig_T[$i][$j]\n\t$ATOMNAME[$i] $ATOMNAME[$i+$j]\n\t$RESNUM[$i] $RESNUM[$i+$j]");
     }else{
     $NOMEGAC++;
     }
    }
   }
   if(exists $ED_T[$i][$j] && ! defined $dihmatch){
    $ED_T[$i][$j]= int(($ED_T[$i][$j] * $PRECISION))/($PRECISION*1.0) ;
    if($MOLTYPE[$i] eq "AMINO"){
     if($ATOMTYPE[$i] eq "BACKBONE" and  $ATOMTYPE[$i+$j] eq "BACKBONE"){
      $NPBB++;
      if($PBBvalue !=$ED_T[$i][$j] && $PBBvalue !=0){
       $fail_log .= failed_message("protein backbone dihedral $i $j\n\t$PBBvalue is before\n\t$ED_T[$i][$j] is the bad one...");
      }else{
       $NPBBC++;
      }
      $PBBvalue=$ED_T[$i][$j];
     }else{
      $NPSC++;
      if($PSCvalue !=$ED_T[$i][$j] && $PSCvalue !=0 && $free eq "no"){
       $fail_log .= failed_message("protein sidechain dihedral $i $j\n\t$PSCvalue is before\n\t$ED_T[$i][$j] is the bad one...");
      }else{
       $NPSCC++;
      }
     $PSCvalue=$ED_T[$i][$j];
     }
    }elsif($MOLTYPE[$i] eq "NUCLEIC"){
     if($ATOMTYPE[$i] eq "BACKBONE" and  $ATOMTYPE[$i+$j] eq "BACKBONE"){
      $NNBB++;     
      if($NABBvalue !=$ED_T[$i][$j] && $NABBvalue != 0 ){
       $fail_log .= failed_message("nucleic backbone dihedral $i $j\n\t$NABBvalue is before\n\t$ED_T[$i][$j] is the bad one...");
      }else{
       $NNBBC++;     
      }
      $NABBvalue=$ED_T[$i][$j];
     }else{
      $NNSC++;     
      if($NASCvalue !=$ED_T[$i][$j] && $NASCvalue !=0){
       $fail_log .= failed_message("nucleic sidechain dihedral $i $j\n\t$NASCvalue is before\n\t$ED_T[$i][$j] is the bad one...");
      }else{
       $NNSCC++;     
      }
      $NASCvalue=$ED_T[$i][$j];
     }
    }elsif($MOLTYPE[$i] eq "LIGAND"){
     $NLIG++;
     if( $ATOMTYPE[$i] ne "BACKBONE" && $ATOMTYPE[$i+$j] ne "BACKBONE"){
      $fail_log .= failed_message("Flexible dihedral assigned to ligand non-backbone. script expects these to be rigid. \n\t$i $j $EDrig_T[$i][$j]\n\t$ATOMNAME[$i] $ATOMNAME[$i+$j]\n\t$RESNUM[$i] $RESNUM[$i+$j]");
      next; # by going to next, this will automatically flag errors with regards to number of rigids
     }
     if($LIGdvalue !=$ED_T[$i][$j] && $LIGdvalue != 0 ){
      $fail_log .= failed_message("backbone atom $i $j\n\t$LIGdvalue is before\n\t$ED_T[$i][$j] is the bad one...");
     }else{
      $NLIGC++;
     }
     $LIGdvalue=$ED_T[$i][$j];
    }else{
     internal_error("Unassigned molecule type");
    }
   }
  }
 }
 if($NRIGID >0){
  if($NRIGID == $NRIGIDC){
   $FAIL{'STRENGTHS OF RIGID DIHEDRALS'}=0;
  }
 }elsif(! $AMINO_PRESENT || $NRIGID==0){
   $FAIL{'STRENGTHS OF RIGID DIHEDRALS'}=-1;
 }
 if($NOMEGA>0){
  if($NOMEGA == $NOMEGAC){
   $FAIL{'STRENGTHS OF OMEGA DIHEDRALS'}=0;
  }
 }elsif(! $AMINO_PRESENT || $NOMEGA==0){
   $FAIL{'STRENGTHS OF OMEGA DIHEDRALS'}=-1;
 }
 if($NPBB>0 && $free eq "no" && ! defined $dihmatch){
  if($NPBB == $NPBBC){
   $FAIL{'STRENGTHS OF PROTEIN BB DIHEDRALS'}=0;
  }
 }elsif(! $AMINO_PRESENT || $free eq "yes" || defined $dihmatch){
   $FAIL{'STRENGTHS OF PROTEIN BB DIHEDRALS'}=-1;
 }
 if($NPSC>0 && $free eq "no"){
  if($NPSC == $NPSCC){
   $FAIL{'STRENGTHS OF PROTEIN SC DIHEDRALS'}=0;
  }
 }elsif(! $AMINO_PRESENT || $free eq "yes"){
   $FAIL{'STRENGTHS OF PROTEIN SC DIHEDRALS'}=-1;
 }elsif($NPSC==0){
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
   $FAIL{'NONZERO LIGAND DIHEDRAL VALUE'}=-1;
 }

 if($model eq "AA" || $model eq "AA-match" ){
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
 
  if($AMINO_PRESENT && $free eq "no" && $NPSC>0){
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

  if($AMINO_PRESENT && $NUCLEIC_PRESENT && $free eq "no"){
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
  if($AMINO_PRESENT && $LIGAND_PRESENT && $free eq "no"){
   if($LIGdvalue == 0){
    $fail_log .= failed_message("Ligand dihedral value is 0.  This should not happen during testing.")
   }else{
    $FAIL{'NONZERO LIGAND DIHEDRAL VALUE'}=0;
    my $RR=$PBBvalue/$LIGdvalue;
    my $RR_TARGET=$PRO_DIH/$LIGAND_DIH;
    if($RR < $MAXTHR*$RR_TARGET and $RR > $MINTHR*$RR_TARGET){
     $FAIL{'AMINO/LIGAND DIHEDRAL RATIO'}=0;
    }else{
     $fail_log .= failed_message("protein: $PBBvalue Ligand: $LIGdvalue\n\tTarget ratio: $RR_TARGET\n\tActual ratio: $RR");
    }
   } 
  }else{
    $FAIL{'AMINO/LIGAND DIHEDRAL RATIO'}=-1;
    $FAIL{'NONZERO LIGAND DIHEDRAL VALUE'}=-1;
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

  my $D_R=$DIH_MAX/$DIH_MIN;
  if(defined $R_P_BB_SC){
   if($D_R > $MAXTHR*4*$R_P_BB_SC  ){
    print "WARNING!!!: range of dihedrals is large\n";
   }
  }
  my $CD_ratio;
  if($DENERGY > 0){
   $CD_ratio=$CONTENERGY/$DENERGY;
   $FAIL{'NONZERO DIHEDRAL ENERGY'}=0;
   if($MAXTHR*$R_CD > $CD_ratio and $MINTHR*$R_CD < $CD_ratio){
   $FAIL{'CONTACT/DIHEDRAL RATIO'}=0;
   }elsif($free eq "yes" or defined $dihmatch){
    $FAIL{'CONTACT/DIHEDRAL RATIO'}=-1;
   }else{
    $fail_log .=failed_message("Contact/Dihedral ratio is off. Expected $R_CD, found $CD_ratio (contacts=$CONTENERGY, dihedrals=$DENERGY");
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
 my $cf=0;
 foreach my $ffields(keys %FOUND)
 {
  if(exists $supported_directives{$ffields}){
   $cf++;
  }else{
   $fail_log .= failed_message("Unrecognized directive $ffields found in top file.")
  }
 }
 if(scalar keys %FOUND == $cf){
  $FAIL{'TOP FIELDS RECOGNIZED'}=0;
 }
 my $NFIELDC=0;
 foreach my $FF(keys %supported_directives){
  if($FOUND{"$FF"} == $supported_directives{"$FF"}){
   $NFIELDC++;
  }elsif($model eq "AA" and $default eq "no" and $FF eq "nonbond_params" and $FOUND{"$FF"} == 1){
   # allow nb params to appear in non-default AA models
   $NFIELDC++;
  }elsif($supported_directives{"$FF"}==1){
   $fail_log .= failed_message("Required directive [ $FF ] not found in top file.  This either means SMOG did not complete, or there was a problem reading the file.  All subsequent output will likely be meaningless.");
  }elsif($supported_directives{"$FF"}==0){
   $fail_log .= failed_message("Directive [ $FF ] found in top file, but it should not for this model.");
  }else{
   smogcheck_error("Serious problem understanding .top file.  A directive may be duplicated.");
  }
 }
 if(scalar keys %supported_directives == $NFIELDC){
  $FAIL{'TOP FIELDS FOUND'}=0;
 }
}

sub identifydih
{
 my ($A1,$A2,$A3,$B1,$B2,$B3)=@_;
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
 return($formed,$phi1,$phi2,$phi3,$phi4); 
}

sub checkvalues
{
 if($model eq "CA"){
  if($theta_gen_N > 0 and $phi_gen_N > 0 ){
   $FAIL{'GENERATION OF ANGLES/DIHEDRALS'}=0;
  }else{
   smogcheck_error("Unable to generate angles ($theta_gen_N), or dihedrals ($phi_gen_N)...");
  }
 }elsif($model eq "AA" || $model eq "AA-match"){
  if($theta_gen_N > 0 and $phi_gen_N > 0 and $improper_gen_N > 0){
   $FAIL{'GENERATION OF ANGLES/DIHEDRALS'}=0;

  }else{
    smogcheck_error("Unable to generate angles ($theta_gen_N), dihedrals ($phi_gen_N), or impropers ($improper_gen_N)...");
  }
 }else{
  smogcheck_error("Unrecognized model when checking values.");
 }
 ## check the energy per dihedral and where the dihedral is SC/BB NA/AMINO
 if($DISP_MAX == 0){
  internal_error("DISP_MAX");
 }

 if($usermap eq "no"){
  if($model eq "AA" || $model eq "AA-match" ){
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
  close(CFILE);
  my $NRD=$NCONTACTS+$bondtype6;
  if($NUMBER_OF_CONTACTS_SHADOW == $NRD){
   $FAIL{'NCONTACTS'}=0;
  }else{
   $fail_log .= failed_message("Same number of contacts not found in contact file and top file!!!! FAIL\n\t$NUMBER_OF_CONTACTS_SHADOW contacts were found in the contact file.\n\t$NRD contacts were found in the top file.");
  }
 }else{
  $FAIL{'OPEN CONTACT FILE'}=-1;
  $FAIL{'NCONTACTS'}=-1;
 }
 if($free eq "yes" ){
  $FAIL{'NCONTACTS'}=-1;
 }
 my $E_TOTAL=$DENERGY+$CONTENERGY;
 my $CTHRESH=$NUMATOMS*10.0/$PRECISION;
 if($model eq "AA" && $free eq "no"){ 
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

sub CheckTemplatesCreated
{
 my ($dir,$prefix)=@_;
 my @arr=("bif","b","sif","nb");
 foreach my $i(@arr){
  unless(-e "$dir/$prefix.$i"){
   internal_error(" $dir/$prefix.$i not created");
  }	
 }
 if($model eq "AA" && $default eq "no" && ! -e "$dir/extras"){
  internal_error(" $dir/extras not created");
 }	

}

sub getdist
{
 my ($handle,$A0,$A1)=@_;
 my $dist;
 if($usermap eq "yes"){
  my $TMP=<$handle>;
  my ($data,$comment)=checkcomment($TMP);
  my @A=split(/\s+/,$data);
  if($#A != 4){internal_error("user-provided contact map has wrong number of fields. See $TMP")};
  $A[4]/=10;;
  return $A[4];
 }else{
  $dist=(($XT[$A0]-$XT[$A1])**2+($YT[$A0]-$YT[$A1])**2+($ZT[$A0]-$ZT[$A1])**2)**(0.5);
  return $dist;
 }
}

sub summary
{
 foreach my $name(keys %FAIL){
  if($FAIL{$name} != -1){
   $CHECKED{$name}=1;
  }
 }

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

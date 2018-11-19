use strict;
use warnings;
use smog_common;
use check_common;
use check_adjust;
use check_table;
use check_ions;
use check_scale;
use check_extract;

# This is the main script that runs SMOG2 tools and then checks to see if the generated files are correct.
print <<EOT;
*****************************************************************************************
                                   smog-tools-check                                   

     smog-tools-check is part of the SMOG 2 distribution, available at smog-server.org     

                  This tool will check your installation of SMOG 2 tools.

                       See the SMOG manual for usage guidelines.

            For questions regarding this script, contact info\@smog-server.org              
*****************************************************************************************
EOT

&checkForModules;
 
my $EXEC_NAME=$ENV{'smog_exec'};
my $EXEC_ADJUST=$ENV{'exec_adjust'};
my $EXEC_IONS=$ENV{'exec_ions'};
my $EXEC_EXTRACT=$ENV{'exec_extract'};
my $EXEC_SCALE=$ENV{'exec_scale'};
my $EXEC_TABLE=$ENV{'exec_table'};

our $TOLERANCE=$ENV{'TOLERANCE'};
our $MAXTHR=1.0+$TOLERANCE;
our $MINTHR=1.0-$TOLERANCE;
our $PRECISION=$ENV{'PRECISION'};

our $PDB_DIR="share/PDB.files";

my $FAILED;
my $message;
my $FAILSUM=0;
my $TESTNUM=0;
#things to check
#all: check for unitialized variables
#	check that they don't crash with FATAL error.
#
#ions: make sure only the right number of ions is added to go
#	make sure that only two directives change: perhaps diff the files first.
#		this will ensure all directives are written.
#		nothing should be unique to original file
#		make sure all parameters are varied
#		make sure it works with CA models, as well.
# 		make sure it works when more than one type of ion is added
#extract: make sure the energetics are correct.  compare to original
#	make sure the restraints are on the right atoms
#	ensure no restraints when off
#	make sure it works with AA and CA models
#	make sure specified files names work
#
# scale: make sure they are correct
# 	correct atoms
# 	all correct atoms
# 	correct ratios
# 	same number of lines before and after 

my $tested=0;
my %checkthese;
my $testall=0;
if(@ARGV>0){
 $testall=1;
 foreach my $name(@ARGV){
  $checkthese{$name}=0;
 }
}
if(defined $checkthese{"ions"} || @ARGV==0){
 print "\nTesting smog_ions\n";
 ($FAILED,$message,$TESTNUM)=check_ions($EXEC_IONS,$PDB_DIR,$TESTNUM);
 if($FAILED >0){$FAILSUM++};
 $tested++;
}
if(defined $checkthese{"extract"} || @ARGV==0){
 print "\nTesting smog_extract\n";
 ($FAILED,$message,$TESTNUM)=check_extract($EXEC_EXTRACT,$PDB_DIR,$TESTNUM);
 if($FAILED >0){$FAILSUM++};
 $tested++;
}
if(defined $checkthese{"tablegen"} || @ARGV==0){
 print "\nTesting smog_tablegen\n";
 ($FAILED,$message,$TESTNUM)=check_table($EXEC_TABLE,$PDB_DIR,$TESTNUM);
 if($FAILED >0){$FAILSUM++};
 $tested++;
}
if(defined $checkthese{"adjustPDB"} || @ARGV==0){
 print "\nTesting smog_adjustPDB\n";
 ($FAILED,$message,$TESTNUM)=check_adjust($EXEC_ADJUST,$PDB_DIR,$TESTNUM);
 if($FAILED >0){$FAILSUM++};
 $tested++;
}
if(defined $checkthese{"scale-energies"} || @ARGV==0){
 print "\nTesting smog_scale-energies\n";
 ($FAILED,$message,$TESTNUM)=check_scale($EXEC_SCALE,$PDB_DIR,$TESTNUM);
 if($FAILED >0){$FAILSUM++};
 $tested++;
}
if($FAILSUM>0){
 print "\n\nSOME TESTS FAILED.  SEE EARLIER MESSAGES\n\n";	
 exit (1);
}elsif($tested==0){
 print "\n\nNo tests performed...\n\n"; 
 exit (1);
}elsif($testall ==0){
 print "\n\nPassed all SMOG tool checks!\n\n"; 
 exit (0);
}else{
 print "\n\nPassed the following checks: "; 
 foreach my $test(keys %checkthese){
  print "$test ";
 }
 print "\n\n";
 exit (0);
}


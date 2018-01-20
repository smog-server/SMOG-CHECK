use strict;
use warnings;
use smog_common;
use check_common;
use check_adjust;
use check_table;
use check_ions;
use check_scale;
use check_extract;

# This is the main script that runs SMOG2 and then checks to see if the generated files are correct.
# This is intended to be a brute-force evaluation of everything that should appear. Since this is
# a testing script, it is not designed to be efficient, but to be thorough, and foolproof...
print <<EOT;
*****************************************************************************************
                                   smog-tools-check                                   

     smog-tools-check is part of the SMOG 2 distribution, available at smog-server.org     

                  This tool will check your installation of SMOG 2 tools.

                       See the SMOG manual for usage guidelines.

            For questions regarding this script, contact info\@smog-server.org              
*****************************************************************************************
EOT

# rerun rend

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
# table: recalculate values and ensure they are the same.
# 	re-evaluate for different parameters
# 	don't worry about switching function?
# 	check the default
# 	check correct file names
#

print "Testing smog_tablegen\n";
($FAILED,$message)=check_table($EXEC_TABLE,$PDB_DIR);
if($FAILED eq "ALL" or $FAILED >0){$FAILSUM++};
print "Testing smog_adjustPDB\n";
($FAILED,$message)=check_adjust($EXEC_ADJUST,$PDB_DIR);
if($FAILED eq "ALL" or $FAILED >0){$FAILSUM++};
print "Testing smog_ions\n";
($FAILED,$message)=check_ions($EXEC_IONS,$PDB_DIR);
if($FAILED eq "ALL" or $FAILED >0){$FAILSUM++};
print "Testing smog_extract\n";
($FAILED,$message)=check_extract($EXEC_EXTRACT,$PDB_DIR);
if($FAILED eq "ALL" or $FAILED >0){$FAILSUM++};
print "Testing smog_scale-energies\n";
($FAILED,$message)=check_scale($EXEC_SCALE,$PDB_DIR);
if($FAILED eq "ALL" or $FAILED >0){$FAILSUM++};

if($FAILSUM>0){
	print "\n\nSOME TESTS FAILED.  SEE EARLIER MESSAGES\n\n";	
	exit (1);
}else{
	print "\n\nPassed all SMOG tool checks!\n\n"; 
	exit (0);
}


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
 
our $EXEC_NAME=$ENV{'smog_exec'};
our $EXEC_ADJUST=$ENV{'smog_adjust'};
our $EXEC_IONS=$ENV{'smog_ions'};
our $EXEC_EXTRACT=$ENV{'smog_extract'};
our $EXEC_SCALE=$ENV{'smog_scale'};
our $EXEC_TABLE=$ENV{'smog_table'};

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
#
#extract: make sure the energetics are correct.  compare to original
#	make sure the restraints are on the right atoms
#	ensure no restraints when off


($FAILED,$message)=check_adjust();

if($FAILED eq "ALL" or $FAILED != 0){
	
} 


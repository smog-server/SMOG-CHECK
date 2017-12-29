package check_ions;
use strict;
use Exporter;
use smog_common;
use check_common;
our @ISA = 'Exporter';
our @EXPORT = qw(check_ions);

sub check_ions
{
 my ($exec,$pdbdir)=@_;
 my $NFAIL=0;
 my $MESSAGE="";
 my %FAIL;
 my $FAILED;
 my $FATAL;
 my $UNINIT;
 my @FAILLIST = ('FATAL','UNINITIALIZED VARIABLES','SMOG FATAL');
 my $FAILED;
 my $printbuffer;
 my $tool="ions";
# init arrays of things to check

  # major index will be parameter set.  Minor index will list name (0), number (1), charge (2), mass (3), C12 (4), C6 (5)
 my @PARAMS = (
 ['K', '10', '1.0', '1.0', '4E-9', '3E-4'],
 ['KR', '4', '-1.1', '1.3', '4.498E-2', '1E-3'],
 );

# perform checks for AA model RNA 
 `smog2 -i $pdbdir/tRNA.pdb -AA -dname AA.tmp > output.smog`;
 my $SMOGFATAL=`grep 'FATAL ERROR' output.smog | wc -l | awk '{print \$1}'`;

 for(my $i=0;$i<=$#PARAMS;$i++){
  print "Checking smog_ions with all-atom model: parameter set $i\n";
  foreach my $item(@FAILLIST){
   $FAIL{$item}=1;
  }
  if($SMOGFATAL ==0){
   $FAIL{"SMOG FATAL"}=0;
  }  

  `$exec -f AA.tmp.top -g AA.tmp.gro -ionnm $PARAMS[$i][0] -ionn  $PARAMS[$i][1] -ionq $PARAMS[$i][2] -ionm $PARAMS[$i][3] -ionC12 $PARAMS[$i][4] -ionC6 $PARAMS[$i][5]   > output.ions`;
  $FATAL=`grep 'FATAL ERROR' output.$tool | wc -l | awk '{print \$1}'`;
  if($FATAL ==0){
   $FAIL{"FATAL"}=0;
  }
  $UNINIT=`grep 'unintialized' output.$tool | wc -l | awk '{print \$1}'`;
  if($UNINIT ==0){
   $FAIL{"UNINITIALIZED VARIABLES"}=0;
  }
  ($FAILED,$printbuffer)=failsum($FATAL,\%FAIL,\@FAILLIST);
 }
 
 return ($FAILED, $printbuffer);

}

return 1;

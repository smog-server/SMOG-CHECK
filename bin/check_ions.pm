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
 my @FAILLIST = ('NON-ZERO EXIT','UNINITIALIZED VARIABLES','OUTPUT GRO NAME','OUTPUT TOP NAME');
 my $FAILED;
 my $printbuffer;
 my $tool="ions";
# init arrays of things to check

  # major index will be parameter set.  Minor index will list name (0), number (1), charge (2), mass (3), C12 (4), C6 (5)
 my @PARAMS = (
 ['K', '10', '1.0', '1.0', '4E-9', '3E-4'],
 ['K+', '4', '-1.1', '1.3', '4.498E-2', '1E-3'],
 );

# perform checks for AA model RNA 
 `smog2 -i $pdbdir/tRNA.pdb -AA -dname AA.tmp > output.smog`;
 my ($SMOGFATAL,$smt)=checkoutput("output.smog");
 unless($SMOGFATAL == 0){
  internal_error("SMOG 2 crashed.  Fix SMOG 2 before testing smog_ions.");
 }
 for(my $i=0;$i<=$#PARAMS;$i++){
  print "Checking smog_ions with all-atom model: parameter set $i\n";
  foreach my $item(@FAILLIST){
   $FAIL{$item}=1;
  }

   `$exec -f AA.tmp.top -g AA.tmp.gro -ionnm $PARAMS[$i][0] -ionn  $PARAMS[$i][1] -ionq $PARAMS[$i][2] -ionm $PARAMS[$i][3] -ionC12 $PARAMS[$i][4] -ionC6 $PARAMS[$i][5]   &> output.$tool`;
   if(-e "smog.ions.top"){$FAIL{"OUTPUT TOP NAME"}=0;}
   if(-e "smog.ions.gro"){$FAIL{"OUTPUT GRO NAME"}=0;}
   ($FATAL,$UNINIT)=checkoutput("output.$tool");
   $FAIL{"NON-ZERO EXIT"}=$FATAL;
   $FAIL{"UNINITIALIZED VARIABLES"}=$UNINIT;

  ($FAILED,$printbuffer)=failsum(\%FAIL,\@FAILLIST);
  print "$printbuffer\n";
 }


# perform checks for CA model protein 
 `smog2 -i $pdbdir/2ci2_v2.pdb -CA -dname CA.tmp > output.smog`;
 ($SMOGFATAL,$smt)=checkoutput("output.smog");
 unless($SMOGFATAL == 0){
  internal_error("SMOG 2 crashed.  Fix SMOG 2 before testing smog_ions.");
 }
 for(my $i=0;$i<=$#PARAMS;$i++){
  print "Checking smog_ions with C-alpha model: parameter set $i\n";
  foreach my $item(@FAILLIST){
   $FAIL{$item}=1;
  }

  `$exec -f CA.tmp.top -g CA.tmp.gro -ionnm $PARAMS[$i][0] -ionn  $PARAMS[$i][1] -ionq $PARAMS[$i][2] -ionm $PARAMS[$i][3] -ionC12 $PARAMS[$i][4] -ionC6 $PARAMS[$i][5]   &> output.$tool`;
  ($FAIL{"NON-ZERO EXIT"},$FAIL{"UNINITIALIZED VARIABLES"})=checkoutput("output.$tool");
   if(-e "smog.ions.top"){$FAIL{"OUTPUT TOP NAME"}=0;}
   if(-e "smog.ions.gro"){$FAIL{"OUTPUT GRO NAME"}=0;}

  ($FAILED,$printbuffer)=failsum(\%FAIL,\@FAILLIST);
  print "$printbuffer\n";
 }
 
 return ($FAILED, $printbuffer);

}

return 1;

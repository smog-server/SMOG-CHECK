package check_scale;
use strict;
use Exporter;
use smog_common;
use check_common;
our @ISA = 'Exporter';
our @EXPORT = qw(check_scale);

sub check_scale
{
 my ($exec,$pdbdir)=@_;
 my $NFAIL=0;
 my $MESSAGE="";
 my %FAIL;
 my $FAILED;
 my $FAILSUM=0;
 my $tool="scale";
 my $printbuffer="";
 my @FAILLIST = ('NON-ZERO EXIT','UNINITIALIZED VARIABLES');
 %FAIL=resettests(\%FAIL,\@FAILLIST);

# generate an AA model RNA 
 `smog2 -i $pdbdir/tRNA.pdb -AA -dname AA.tmp > output.smog`;
 my ($SMOGFATAL,$smt)=checkoutput("output.smog");
 unless($SMOGFATAL == 0){
  internal_error("SMOG 2 crashed.  Fix SMOG 2 before testing smog_ions.");
 }

 print "Checking smog_scale-energies with all-atom model\n";

 %FAIL=resettests(\%FAIL,\@FAILLIST);
 `$exec -f AA.tmp.top -n share/PDB.files/sample.AA.ndx -rc 1.5 -rd 1.2 < $pdbdir/in.groups &> output.$tool`;
 ($FAIL{"NON-ZERO EXIT"},$FAIL{"UNINITIALIZED VARIABLES"})=checkoutput("output.$tool");

## add checks here
#check with different output names
#verify that if 
 ($FAILED,$printbuffer)=failsum(\%FAIL,\@FAILLIST);
 $FAILSUM += $FAILED;
 if($FAILED !=0){
  savefailed(1,("output.$tool","smog.rescaled.top"));
  print "$printbuffer\n";
 }else{
  clearfiles(("output.$tool","smog.rescaled.top"));
 }
 return ($FAILSUM, $printbuffer);

}

return 1;

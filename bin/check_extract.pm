package check_extract;
use strict;
use Exporter;
use smog_common;
use check_common;
our @ISA = 'Exporter';
our @EXPORT = qw(check_extract);

sub check_extract
{
 my ($exec,$pdbdir)=@_;
 my $NFAIL=0;
 my $MESSAGE="";
 my %FAIL;
 my $FAILED;
 my $FATAL;
 my $UNINIT;
 my $printbuffer;
 my $tool="extract";
 my @FAILLIST = ('NON-ZERO EXIT','UNINITIALIZED VARIABLES');


 %FAIL=resettests(\%FAIL,\@FAILLIST);

# generate an AA model RNA 
 `smog2 -i $pdbdir/tRNA.pdb -AA -dname AA.tmp > output.smog`;
 my ($SMOGFATAL,$smt)=checkoutput("output.smog");
 unless($SMOGFATAL == 0){
  internal_error("SMOG 2 crashed.  Fix SMOG 2 before testing smog_ions.");
 }
  print "Checking smog_extract with all-atom model: no restaints\n";
  for(my $group=0;$group<3;$group++){

   %FAIL=resettests(\%FAIL,\@FAILLIST);
   print "\tChecking with index group $group\n";
   `echo $group | $exec -f AA.tmp.top -g AA.tmp.gro -n $pdbdir/sample.AA.ndx  &> output.$tool`;
   ($FAIL{"NON-ZERO EXIT"},$FAIL{"UNINITIALIZED VARIABLES"})=checkoutput("output.$tool");

   ($FAILED,$printbuffer)=failsum(\%FAIL,\@FAILLIST);
   print "$printbuffer\n";
  } 
 return ($FAILED, $printbuffer);

}

return 1;

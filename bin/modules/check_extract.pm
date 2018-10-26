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
 my $FAILSUM=0;
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
  internal_error("SMOG 2 crashed.  Fix SMOG 2 before testing smog_extract.");
 }
  print "Checking smog_extract with all-atom model: no restaints\n";
  for(my $group=0;$group<3;$group++){

   %FAIL=resettests(\%FAIL,\@FAILLIST);
   print "\tChecking with index group $group\n";
   `echo $group | $exec -f AA.tmp.top -g AA.tmp.gro -n $pdbdir/sample.AA.ndx  &> output.$tool`;
   ($FAIL{"NON-ZERO EXIT"},$FAIL{"UNINITIALIZED VARIABLES"})=checkoutput("output.$tool");

   ($FAILED,$printbuffer)=failsum(\%FAIL,\@FAILLIST);
   $FAILSUM += $FAILED;
   if($FAILED !=0){
    savefailed("AA.nores.$group",("output.$tool","extracted.top","extracted.gro","atomindex.map"));
    print "$printbuffer\n";
   }else{
    clearfiles(("output.$tool","extracted.top","extracted.gro","atomindex.map"));
   }
  } 
  clearfiles(("AA.tmp.top","AA.tmp.gro"));

  print "Checking smog_extract with all-atom model: no restaints: non-standard fields\n";
  for(my $group=0;$group<2;$group++){

   %FAIL=resettests(\%FAIL,\@FAILLIST);
   print "\tChecking with index group $group\n";
   `echo $group | $exec -f $pdbdir/large.top -g $pdbdir/large.gro -n $pdbdir/large.ndx  &> output.$tool`;
   ($FAIL{"NON-ZERO EXIT"},$FAIL{"UNINITIALIZED VARIABLES"})=checkoutput("output.$tool");

   ($FAILED,$printbuffer)=failsum(\%FAIL,\@FAILLIST);
   $FAILSUM += $FAILED;
   if($FAILED !=0){
    savefailed("AA.nores.nonstandard.$group",("output.$tool","extracted.top","extracted.gro","atomindex.map"));
    print "$printbuffer\n";
   }else{
    clearfiles(("output.$tool","extracted.top","extracted.gro","atomindex.map"));
   }
  } 

  print "Checking smog_extract with all-atom model: restaints: non-standard fields\n";
  for(my $group=0;$group<2;$group++){

   %FAIL=resettests(\%FAIL,\@FAILLIST);
   print "\tChecking with index group $group\n";
   `echo $group | $exec -f $pdbdir/large.top -g $pdbdir/large.gro -n $pdbdir/large.ndx -restraints 100 &> output.$tool`;
   ($FAIL{"NON-ZERO EXIT"},$FAIL{"UNINITIALIZED VARIABLES"})=checkoutput("output.$tool");

   ($FAILED,$printbuffer)=failsum(\%FAIL,\@FAILLIST);
   $FAILSUM += $FAILED;
   if($FAILED !=0){
    savefailed("AA.res.nonstandard.$group",("output.$tool","extracted.top","extracted.gro","atomindex.map","restrained.map"));
    print "$printbuffer\n";
   }else{
    clearfiles(("output.$tool","extracted.top","extracted.gro","atomindex.map","restrained.map"));
   }
  } 

 return ($FAILSUM, $printbuffer);

}

return 1;

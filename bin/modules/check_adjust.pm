package check_adjust;
use strict;
use Exporter;
use smog_common;
use check_common;
our @ISA = 'Exporter';
our @EXPORT = qw(check_adjust);

sub check_adjust
{
 my ($exec,$pdbdir)=@_;
 my $NFAIL=0;
 my $MESSAGE="";
 my %FAIL;
 my $FAILED;
 my $FAILSUM=0;
 my $UNINIT;
 my $LINESorig=0;
 my $origpdb="$pdbdir/3PTA.preadjust.pdb";
 my $newpdb="testname.pdb";
 my $tool="adjust";
 open(ORIG,"$origpdb") or internal_error("Unable to open $origpdb");
 while(<ORIG>){
  $LINESorig++;
 }
 my @FAILLIST = ('NON-ZERO EXIT','UNINITIALIZED VARIABLES','OUTPUT NAME','FILE LENGTH');


 print "Checking smog_adjustPDB with default naming.\n";
 %FAIL=resettests(\%FAIL,\@FAILLIST);

 if(-e "adjusted.pdb"){
  `rm adjusted.pdb`;
 }
 `$exec -default -i $origpdb &> output.$tool`;
 if(-e "adjusted.pdb"){
  $FAIL{"OUTPUT NAME"}=0;
 }

 ($FAIL{"NON-ZERO EXIT"},$FAIL{"UNINITIALIZED VARIABLES"})=checkoutput("output.$tool");
 
 my $LINESnew=0;
 open(NEW,"adjusted.pdb") or internal_error("Unable to open adjusted.pdb");
 while(<NEW>){
  $LINESnew++;
 }
 if($LINESnew==$LINESorig){
  $FAIL{"FILE LENGTH"}=0;
 }
 my ($FAILED,$printbuffer)=failsum(\%FAIL,\@FAILLIST);
 $FAILSUM += $FAILED;
 if($FAILED !=0){
  savefailed(1,("adjusted.pdb","output.$tool"));
  print "$printbuffer\n";
 }else{
  clearfiles(("adjusted.pdb","output.$tool"));
 }

 print "Checking smog_adjustPDB with user-specified file name.\n";
 %FAIL=resettests(\%FAIL,\@FAILLIST);
 if(-e "$newpdb"){
  `rm $newpdb`;
 }
 `$exec -default -i $origpdb -o $newpdb &> output.$tool`;
 if(-e "$newpdb"){
  $FAIL{"OUTPUT NAME"}=0;
 }

 ($FAIL{"NON-ZERO EXIT"},$FAIL{"UNINITIALIZED VARIABLES"})=checkoutput("output.$tool");

 my $LINESnew=0;
 open(NEW,"$newpdb") or internal_error("Unable to open adjusted.pdb");
 while(<NEW>){
  $LINESnew++;
 }
 if($LINESnew==$LINESorig){
  $FAIL{"FILE LENGTH"}=0;
 }
 my ($FAILED,$printbuffer)=failsum(\%FAIL,\@FAILLIST);
 $FAILSUM += $FAILED;
 if($FAILED !=0){
  savefailed(2,("$newpdb","output.$tool"));
  print "$printbuffer\n";
 }else{
  clearfiles(("$newpdb","output.$tool"));
 }

 return ($FAILSUM, $printbuffer);

}

return 1;

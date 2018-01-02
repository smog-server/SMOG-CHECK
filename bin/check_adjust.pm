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
 my $UNINIT;
 my $LINESorig=0;
 my $origpdb="$pdbdir/3PTA.preadjust.pdb";
 my $newpdb="testname.pdb";
 my $tool="adjust";
 open(ORIG,"$origpdb") or internal_error("Unable to open $origpdb");
 while(<ORIG>){
  $LINESorig++;
 }
 my @FAILLIST = ('FATAL','UNINITIALIZED VARIABLES','OUTPUT NAME','FILE LENGTH');


 print "Checking smog_adjustPDB with default naming.\n";
 foreach my $item(@FAILLIST){
 	$FAIL{$item}=1;
 }
 if(-e "adjusted.pdb"){
  `rm adjusted.pdb`;
 }
 `$exec -default -i $origpdb > output.$tool`;
 if(-e "adjusted.pdb"){
  $FAIL{"OUTPUT NAME"}=0;
 }

 ($FAIL{"FATAL"},$FAIL{"UNINITIALIZED VARIABLES"})=checkoutput("output.$tool");
 
 my $LINESnew=0;
 open(NEW,"adjusted.pdb") or internal_error("Unable to open adjusted.pdb");
 while(<NEW>){
  $LINESnew++;
 }
 if($LINESnew==$LINESorig){
  $FAIL{"FILE LENGTH"}=0;
 }
 my ($FAILED,$printbuffer)=failsum(\%FAIL,\@FAILLIST);
 print "$printbuffer\n";
 print "Checking smog_adjustPDB with user-specified file name.\n";
 foreach my $item(@FAILLIST){
 	$FAIL{$item}=1;
 }
 if(-e "$newpdb"){
  `rm $newpdb`;
 }
 `$exec -default -i $origpdb -o $newpdb > output.$tool`;
 if(-e "$newpdb"){
  $FAIL{"OUTPUT NAME"}=0;
 }

 ($FAIL{"FATAL"},$FAIL{"UNINITIALIZED VARIABLES"})=checkoutput("output.$tool");

 my $LINESnew=0;
 open(NEW,"$newpdb") or internal_error("Unable to open adjusted.pdb");
 while(<NEW>){
  $LINESnew++;
 }
 if($LINESnew==$LINESorig){
  $FAIL{"FILE LENGTH"}=0;
 }
 my ($FAILED,$printbuffer)=failsum(\%FAIL,\@FAILLIST);
 print "$printbuffer\n";
 
 return ($FAILED, $printbuffer);

}

return 1;
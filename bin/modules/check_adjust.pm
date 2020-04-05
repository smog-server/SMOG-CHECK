package check_adjust;
use strict;
use Exporter;
use smog_common;
use check_common;
our @ISA = 'Exporter';
our @EXPORT = qw(check_adjust);

sub check_adjust
{
 my ($exec,$smogexec,$pdbdir)=@_;
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
 my @FAILLIST = ('NON-ZERO EXIT','OUTPUT NAME','FILE LENGTH','SMOG RUNS');

 print "\tChecking smog_adjustPDB with legacy naming.\n";
 %FAIL=resettests(\%FAIL,\@FAILLIST);
 removeifexists("adjusted.pdb");
 `$exec -default -legacy -i $origpdb &> output.$tool`;
 if(-e "adjusted.pdb"){
  $FAIL{"OUTPUT NAME"}=0;
 }

 $FAIL{"NON-ZERO EXIT"}=$?;
 if ($FAIL{"NON-ZERO EXIT"} == 0){
  my $LINESnew=0;
  open(NEW,"adjusted.pdb") or internal_error("Unable to open adjusted.pdb");
  while(<NEW>){
   $LINESnew++;
  }
  if($LINESnew==$LINESorig-1){
   # +1 because a comment is added at the top
   # but, we are also removing 2 lines, since they are consecutive TER lines
   $FAIL{"FILE LENGTH"}=0;
  }
  my $smogout=`$smogexec -AA -i adjusted.pdb -dname adjusted &> smog.output`;
  $FAIL{'SMOG RUNS'}=$?;
 }

 my ($FAILED,$printbuffer)=failsum(\%FAIL,\@FAILLIST);
 $FAILSUM += $FAILED;
 if($FAILED !=0){
  savefailed(1,("adjusted.pdb","output.$tool","adjusted.gro","adjusted.top","adjusted.ndx","adjusted.contacts","smog.output"));
  print "$printbuffer\n";
 }else{
  print "\n";
  clearfiles(("adjusted.pdb","output.$tool","adjusted.gro","adjusted.top","adjusted.ndx","adjusted.contacts" ,"smog.output"));
 }

 print "\tChecking smog_adjustPDB with user-specified file name (legacy).\n";
 %FAIL=resettests(\%FAIL,\@FAILLIST);
 removeifexists("$newpdb");
 `$exec -default -legacy -i $origpdb -o $newpdb &> output.$tool`;
 if(-e "$newpdb"){
  $FAIL{"OUTPUT NAME"}=0;
 }

 $FAIL{"NON-ZERO EXIT"}=$?;
 if($FAIL{"NON-ZERO EXIT"} == 0){
  my $LINESnew=0;
  open(NEW,"$newpdb") or internal_error("Unable to open adjusted.pdb");
  while(<NEW>){
   $LINESnew++;
  }
  if($LINESnew==$LINESorig-1){
   $FAIL{"FILE LENGTH"}=0;
  }
  my $smogout=`$smogexec -AA -i $newpdb -dname adjusted &> smog.output`;
  $FAIL{'SMOG RUNS'}=$?;
 }
 my ($FAILED,$printbuffer)=failsum(\%FAIL,\@FAILLIST);
 $FAILSUM += $FAILED;
 if($FAILED !=0){
  savefailed(2,("adjusted.pdb","$newpdb","output.$tool","adjusted.gro","adjusted.top","adjusted.ndx","adjusted.contacts" ,"smog.output"));
  print "$printbuffer\n";
 }else{
  print "\n";
  clearfiles(("adjusted.pdb","$newpdb","output.$tool","adjusted.gro","adjusted.top","adjusted.ndx","adjusted.contacts" ,"smog.output"));
 }


 my $origpdb="$pdbdir/mangled.names.pdb";

 print "\tChecking smog_adjustPDB with default exact matching.\n";
 %FAIL=resettests(\%FAIL,\@FAILLIST);
 removeifexists("$newpdb");
 `$exec -default -i $origpdb -o $newpdb &> output.$tool`;
 if(-e "$newpdb"){
  $FAIL{"OUTPUT NAME"}=0;
 }

 $FAIL{"NON-ZERO EXIT"}=$?;
 if($FAIL{"NON-ZERO EXIT"} == 0){
  my $LINESnew=0;
  open(NEW,"$newpdb") or internal_error("Unable to open $newpdb");
  while(<NEW>){
   $LINESnew++;
  }
  if($LINESnew==$LINESorig-1){
   $FAIL{"FILE LENGTH"}=0;
  }
  my $smogout=`$smogexec -AA -i $newpdb -dname adjusted &> smog.output`;
  $FAIL{'SMOG RUNS'}=$?;
 }
 my ($FAILED,$printbuffer)=failsum(\%FAIL,\@FAILLIST);
 $FAILSUM += $FAILED;
 if($FAILED !=0){
  savefailed(2,("adjusted.pdb","$newpdb","output.$tool","adjusted.gro","adjusted.top","adjusted.ndx","adjusted.contacts" ,"smog.output"));
  print "$printbuffer\n";
 }else{
  print "\n";
  clearfiles(("adjusted.pdb","$newpdb","output.$tool","adjusted.gro","adjusted.top","adjusted.ndx","adjusted.contacts" ,"smog.output"));
 }

 return ($FAILSUM, $printbuffer);

}

return 1;

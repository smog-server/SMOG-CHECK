package check_common;
use strict;
use Exporter;

our $PDB_DIR;
our @ISA = 'Exporter';
our @EXPORT =
qw(internal_error smogcheck_error failed_message failsum checkoutput filediff);

sub internal_error
{
 my ($MESSAGE)=@_;
 chomp($MESSAGE);
  print "\n\nInternal error : $MESSAGE\n\n";
  print "Please report this to info\@smog-server.org\n";
  print "Quitting.\n";
  exit(2);
}

sub smogcheck_error
{
 my ($MESSAGE)=@_;
 chomp($MESSAGE);
  print "\n\nERROR: SMOG-CHECK CRASH: $MESSAGE\n\n";
  print "Quitting.\n";
  exit(1);
}

sub failed_message
{
 my ($MESSAGE)=@_;
 chomp($MESSAGE);
 $MESSAGE=sprintf ("FAILED TEST: %s\n\n", $MESSAGE);
 return $MESSAGE;
}

sub failsum
{
 my ($FAIL,$FAILLIST)=@_;
 my %FAIL=%{$FAIL};
 my @FAILLIST=@{$FAILLIST};
 my $printbuffer="";
 my $NFAILED=0;
 my $NPASSED=0;
 my $NNA=0;
 my $FAILED=0;
# make sure we didn't assign a test entry that is not being monitored
 foreach my $tt(keys %FAIL){
 my $N=0;
 for (my $J=0;$J<=$#FAILLIST;$J++){
  if($FAILLIST[$J] eq "$tt"){
   last;
  }
  $N++; 
 }
  if($N-1==$#FAILLIST){
    internal_error("FAILLIST entry $tt not defined");
  }
 }
 if($FAIL{"NON-ZERO EXIT"}==0){
  $printbuffer .= sprintf ("\n     LIST OF FAILED TESTS:\n");
  foreach my $TEST (@FAILLIST){
   if($FAIL{$TEST}>0){
    $printbuffer .= sprintf ("        %s CHECK\n",$TEST);
    $FAILED++;
    $NFAILED++;
   }elsif($FAIL{$TEST}==0){
    $NPASSED++;
   }elsif($FAIL{$TEST}==-1){
    $NNA++;
   }else{
    internal_error("FAILLIST entry $TEST error");
   }
  }
  if($NFAILED==0){
   $printbuffer="";
  }
 }else{
  $FAILED=1;
  $printbuffer = sprintf ("\tFATAL ERROR ENCOUNTERED\n");
 }
 print "test results\n";
 print "\t passed : $NPASSED\n";
 if($NFAILED != 0){
  
 print "\t failed : $NFAILED\n";
 }
 print "\t N/A    : $NNA\n";

 return ($FAILED,$printbuffer);

}

##################################
# routines that check for errors #
# ################################

sub checkoutput
{
 my ($filename)=@_;
 open(FILE,"$filename") or internal_error("can not open $filename for reading.");
 my $fatal=0;
 my $uninit=0;
 my $exitcode=$?;
 while(<FILE>){
  $uninit=1 if /unitialized/;
 }
 if($exitcode >0){
  $exitcode=1; 
 }
 close(FILE);
 return ($exitcode,$uninit);	
}

###################################
# check if two files are identical#
# #################################

sub filediff
{
 my ($file1,$file2)=@_;
 my @info1;
 my @info2;
 open(FILE1,"$file1") or internal_error("can not open $file1 for reading.");
 my $I1=0;
 while(<FILE1>){
  $info1[$I1]=$_;
  $I1++;
 }
 close(FILE1);
 open(FILE2,"$file2") or internal_error("can not open $file2 for reading.");
 my $I2=0;
 while(<FILE2>){
  $info2[$I2]=$_;
  $I2++;
 }
 close(FILE2);

 if($I1 != $I2){
  # files are different
  return 1;
 }

 my $ndiff=0;
 for(my $I=0;$I<$I1;$I++){
  if($info1[$I] ne $info2[$I]){
   $ndiff++;
  }
 }
 return $ndiff;
}


return 1;


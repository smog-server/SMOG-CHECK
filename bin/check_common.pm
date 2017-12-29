package check_common;
use strict;
use Exporter;

our $PDB_DIR;
our @ISA = 'Exporter';
our @EXPORT =
qw(internal_error smogcheck_error failed_message failsum checkfatal checkuninit);

sub internal_error
{
 my ($MESSAGE)=@_;
 chomp($MESSAGE);
  print "\n\nInternal error at $MESSAGE\n\n";
  print "Please report this to info\@smog-server.org\n";
  print "Quitting.\n";
  exit;
}

sub smogcheck_error
{
 my ($MESSAGE)=@_;
 chomp($MESSAGE);
  print "\n\nERROR: SMOG-CHECK CRASH: $MESSAGE\n\n";
  print "Quitting.\n";
  exit;
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
 my ($FATAL,$FAIL,$FAILLIST)=@_;
 my %FAIL=%{$FAIL};
 my @FAILLIST=@{$FAILLIST};
 my $printbuffer="";
 my $NFAILED=0;
 my $NPASSED=0;
 my $NNA=0;
 my $FAILED=0;
 if($FATAL==0){
  $printbuffer .= sprintf ("\n     LIST OF FAILED TESTS:\n");
  foreach my $TEST (@FAILLIST){
   if($FAIL{$TEST}==1){
    $printbuffer .= sprintf ("        %s CHECK\n",$TEST);
    $FAILED++;
    $NFAILED++;
   }elsif($FAIL{$TEST}==0){
    $NPASSED++;
   }elsif($FAIL{$TEST}==-1){
    $NNA++;
   }else{
    internal_error("$TEST");
   }
  }
  if($NFAILED==0){
   $printbuffer="";
  }
 }else{
  $FAILED="ALL";
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

sub checkfatal
{
 my ($filename)=@_;
 open(FILE,"$filename") or internal_error("can not open $filename for reading.");
 my $fatal=0;
 while(<FILE>){
  $fatal++ if /FATAL ERROR/;
 }
 return $fatal;	

}

sub checkuninit
{
 my ($filename)=@_;
 open(FILE,"$filename") or internal_error("can not open $filename for reading.");
 my $uninit=0;
 while(<FILE>){
  $uninit++ if /unitialized/;
 }
 return $uninit;	

}

 
return 1;


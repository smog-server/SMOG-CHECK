package check_common;
use strict;
use Exporter;

our $PDB_DIR;
our @ISA = 'Exporter';
our @EXPORT =
qw(internal_error smogcheck_error savefailed clearfiles failed_message failsum checkoutput filediff resettests compare_table timediff);

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

sub savefailed
{
 my ($suffix,@A)=@_;
 foreach my $name (@A)
 {
  if(-e $name){
   `mv $name FAILED.tools/$name.$suffix`;
  }
 }
}

sub clearfiles
{
 my (@A)=@_;
 foreach my $name (@A)
 {
  if(-e $name){
   `rm $name`;
  }
 }
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
    $printbuffer .= sprintf ("        %s\n",$TEST);
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
 print "\ttest results\n";
 print "\tpassed : $NPASSED\n";
 if($NFAILED != 0){
  
 print "\tfailed : $NFAILED\n";
 }
 print "\tN/A    : $NNA\n";

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
  $uninit=1 if /uninitialized|masks/;
 }
 if($exitcode >0){
  $exitcode=1; 
 }
 close(FILE);
 return ($exitcode,$uninit);	
}

sub load_file
{
 my ($file1)=@_;
 my @info;
 my $I;
 if(open(FILE1,"$file1")){
  while(<FILE1>){
   $info[$I]=$_;
   $I++;
  }
  close(FILE1);
  return ($I,\@info);
 }else{
  return (-1,1);
 }
}

###################################
# check if two files are identical#
# #################################

sub filediff
{
 my ($file1,$file2)=@_;
 my @info1;
 my @info2;
 my $I2=0;
 my ($I1,$data)=load_file($file1);
 if($I1==-1){
  # could not open file
  return 1;
 }else{
  @info1=@{$data};
 }
 my ($I2,$data)=load_file($file2);
 if($I2==-1){
  # could not open file
  return 1;
 }else{
  @info2=@{$data};
 }

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

sub resettests
{
 my ($FAIL,$FAILLIST)=@_;
 my %FAIL=%{$FAIL};
 my @FAILLIST=@{$FAILLIST};
 foreach my $item(@FAILLIST){
        $FAIL{$item}=1;
 }
 return %FAIL;
}

sub compare_table
{
 my ($file1,$file2)=@_;
 my @info1;
 my @info2;
 my ($I1,$data)=load_file($file1);
 if($I1==-1){
  # could not open file
  return 1;
 }else{
  @info1=@{$data};
 }
 my ($I2,$data)=load_file($file2);
 if($I2==-1){
  # could not open file
  return 1;
 }else{
  @info2=@{$data};
 }

 if($I1 != $I2){
  # files are different
  return 1;
 }

 my $ndiff=0;
 for(my $I=0;$I<$I1;$I++){
  if($info1[$I] =~ m/^#/ && $info2[$I] =~ m/^#/){
   next;
  }
  my @A=split(/\s+/,$info1[$I]);
  my @B=split(/\s+/,$info2[$I]);
  if ($#A != $#B){
   return 1;
  }
  for(my $J=0;$J<=$#A;$J++){
   if($info1[$J] != 0 && $info2[$J] != 0 && abs($info1[$J]-$info2[$J])/abs($info1[$J]) > 0.00001){
    $ndiff++;
   }
  } 
 }
 return $ndiff;
}

sub timediff
{
	my ($time_last)=@_;
	my $time=time-$time_last;
	print "$time seconds\n";
	$time_last=time;
	return $time_last;
}


return 1;


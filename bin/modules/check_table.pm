package check_table;
use strict;
use Exporter;
use smog_common;
use check_common;
our @ISA = 'Exporter';
our @EXPORT = qw(check_table);

sub check_table
{
 my ($exec,$pdbdir)=@_;
 my $NFAIL=0;
 my $MESSAGE="";
 my %FAIL;
 my $FAILED;
 my $FAILSUM=0;
 my $tool="table";
 my @FAILLIST = ('NON-ZERO EXIT','UNINITIALIZED VARIABLES','CORRECT VALUES');
 %FAIL=resettests(\%FAIL,\@FAILLIST);

 print "Checking default table\n"; 
 `$exec &> output.$tool`;
 ($FAIL{"NON-ZERO EXIT"},$FAIL{"UNINITIALIZED VARIABLES"})=checkoutput("output.$tool");
 $FAIL{"CORRECT VALUES"}=compare_table("table.xvg","share/refs/table_def.xvg");
 my ($FAILED,$printbuffer)=failsum(\%FAIL,\@FAILLIST);
 $FAILSUM += $FAILED;
 if($FAILED !=0){
  savefailed(1,("table.xvg","output.$tool"));
  print "$printbuffer\n";
 }else{
  clearfiles(("table.xvg","output.$tool"));
 }

 %FAIL=resettests(\%FAIL,\@FAILLIST);
 print "Checking custom table\n"; 
 `$exec -M 10 -n 6 -ic 150 -tl 3 -sd 0.8 -sc 1.2 -table table.2.xvg &> output.$tool`;
 ($FAIL{"NON-ZERO EXIT"},$FAIL{"UNINITIALIZED VARIABLES"})=checkoutput("output.$tool");
 $FAIL{"CORRECT VALUES"}=compare_table("table.2.xvg","share/refs/table.2.xvg");
 my ($FAILED,$printbuffer)=failsum(\%FAIL,\@FAILLIST);
 if($FAILED !=0){
  savefailed(2,("table.2.xvg","output.$tool"));
  print "$printbuffer\n";
 }else{
  clearfiles(("table.2.xvg","output.$tool"));
 }

 $FAILSUM += $FAILED;
 return ($FAILSUM, $printbuffer);
}

return 1;

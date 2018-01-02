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
 my $tool="table";
 my @FAILLIST = ('NON-ZERO EXIT','UNINITIALIZED VARIABLES');
 foreach my $item(@FAILLIST){
 	$FAIL{$item}=1;
 }

 print "Checking default table\n"; 
 `$exec > output.$tool`;
 ($FAIL{"NON-ZERO EXIT"},$FAIL{"UNINITIALIZED VARIABLES"})=checkoutput("output.$tool");
 
 my ($FAILED,$printbuffer)=failsum(\%FAIL,\@FAILLIST);
 
 return ($FAILED, $printbuffer);

}

return 1;

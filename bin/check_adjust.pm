package smog_adjust;
use strict;
use Exporter;
use smog_common;
use check_common;

sub check_adjust
{
 my $NFAIL=0;
 my $MESSAGE="";
 my %FAIL;
 my $FAILED;
 my $FATAL;
 my @FAILLIST = ('FATAL','UNINITIALIZED VARIABLES');
 foreach my $item(@FAILLIST){
 	$FAIL{$item}=1;
 }
 
 
 
 my ($FAILED,$printbuffer)=failsum($FATAL,\%FAIL,\@FAILLIST);
 
 return ($FAILED, $printbuffer);

}

return 1;

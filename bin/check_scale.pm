package check_scale;
use strict;
use Exporter;
use smog_common;
use check_common;
our @ISA = 'Exporter';
our @EXPORT = qw(check_scale);

sub check_scale
{
 my ($exec,$pdbdir)=@_;
 my $NFAIL=0;
 my $MESSAGE="";
 my %FAIL;
 my $FAILED;
 my $FATAL;
 my @FAILLIST = ('FATAL','UNINITIALIZED VARIABLES');
 foreach my $item(@FAILLIST){
 	$FAIL{$item}=1;
 }
 
 `$exec > output.scale`;
 
 my ($FAILED,$printbuffer)=failsum(\%FAIL,\@FAILLIST);
 
 return ($FAILED, $printbuffer);

}

return 1;

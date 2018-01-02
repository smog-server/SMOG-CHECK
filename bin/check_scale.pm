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
 my $tool="scale";
 my $printbuffer="";
 my @FAILLIST = ('NON-ZERO EXIT','UNINITIALIZED VARIABLES','SMOG FATAL');
 foreach my $item(@FAILLIST){
 	$FAIL{$item}=1;
 }

# generate an AA model RNA 
 `smog2 -i $pdbdir/tRNA.pdb -AA -dname AA.tmp > output.smog`;
 my ($SMOGFATAL,$smt)=checkoutput("output.smog");

  print "Checking smog_scale-energies with all-atom model\n";
   foreach my $item(@FAILLIST){
    $FAIL{$item}=1;
   }
   $FAIL{"SMOG FATAL"}=$SMOGFATAL ;
   `smog_scale-energies -f AA.tmp.top -n share/PDB.files/sample.AA.ndx -rc 1.5 -rd 1.2 < $pdbdir/in.groups > output.$tool`;
   ($FAIL{"NON-ZERO EXIT"},$FAIL{"UNINITIALIZED VARIABLES"})=checkoutput("output.$tool");


## add checks here
#check with different output names
#verify that if 

   ($FAILED,$printbuffer)=failsum(\%FAIL,\@FAILLIST);
   print "$printbuffer\n";

 return ($FAILED, $printbuffer);

}

return 1;

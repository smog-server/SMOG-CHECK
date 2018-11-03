package check_ions;
use strict;
use Exporter;
use smog_common;
use check_common;
our @ISA = 'Exporter';
our @EXPORT = qw(check_ions);

# in supported_directives, a value of 1 means is it required, 0 is not supported. >1 means optional
our %supported_directives = ( 'defaults' => '1',
        'atomtypes' => '1',
        'moleculetype' => '1',
        'nonbond_params' => '2',
        'atoms' => '1',
        'bonds' => '1',
        'angles' => '1',
        'dihedrals' => '1',
        'pairs' => '1',
        'exclusions' => '1',
        'system' => '1',
        'molecules' => '1',
        'position_restraints' => '0'
        );

sub check_ions
{
 my ($exec,$pdbdir)=@_;
 my $NFAIL=0;
 my $MESSAGE="";
 my %FAIL;
 my $FAILED;
 my $FATAL;
 my $UNINIT;
 my @FAILLIST = ('NON-ZERO EXIT','UNINITIALIZED VARIABLES','OUTPUT GRO NAME','OUTPUT TOP NAME','CHECK TOP');
 my $FAILSUM=0;
 my $printbuffer;
 my $tool="ions";
# init arrays of things to check

  # major index will be parameter set.  Minor index will list name (0), number (1), charge (2), mass (3), C12 (4), C6 (5)
 my @PARAMS = (
 ['K', '10', '1.0', '1.0', '4E-9', '3E-4'],
 ['K+', '4', '-1.1', '1.3', '4.498E-2', '1E-3'],
 ['CL', '2', '-0.1', '1.2', '1.498E-2', '3E-3'],
 );

# perform checks for AA model RNA 
 `smog2 -i $pdbdir/tRNA.pdb -AA -dname AA.tmp > output.smog`;
 my ($SMOGFATAL,$smt)=checkoutput("output.smog");
 unless($SMOGFATAL == 0){
  internal_error("SMOG 2 crashed.  Fix SMOG 2 before testing smog_ions.");
 }else{
  clearfiles("output.smog");
 }

 for(my $i=0;$i<=$#PARAMS;$i++){
  print "\tChecking smog_ions with all-atom model: parameter set $i\n";

  %FAIL=resettests(\%FAIL,\@FAILLIST);

  `$exec -f AA.tmp.top -g AA.tmp.gro -ionnm $PARAMS[$i][0] -ionn  $PARAMS[$i][1] -ionq $PARAMS[$i][2] -ionm $PARAMS[$i][3] -ionC12 $PARAMS[$i][4] -ionC6 $PARAMS[$i][5]   &> output.$tool`;
  if($i>0){
   # if not the first test, then check everything
   if(-e "smog.ions.top"){$FAIL{"OUTPUT TOP NAME"}=0;}
   if(-e "smog.ions.gro"){$FAIL{"OUTPUT GRO NAME"}=0;}
   ($FATAL,$UNINIT)=checkoutput("output.$tool");

   $FAIL{"NON-ZERO EXIT"}=$FATAL;
   $FAIL{"UNINITIALIZED VARIABLES"}=$UNINIT;
   $FAIL{"CHECK TOP"}=checktopions("AA.tmp.top","smog.ions.top",$PARAMS[$i][0],$PARAMS[$i][1],$PARAMS[$i][2],$PARAMS[$i][3],$PARAMS[$i][4],$PARAMS[$i][5]);
   ($FAILED,$printbuffer)=failsum(\%FAIL,\@FAILLIST);
   $FAILSUM += $FAILED;
   if($FAILED !=0){
    savefailed("AA.$i",("output.$tool","smog.ions.top","smog.ions.gro"));
    print "$printbuffer\n";
   }else{
    clearfiles(("output.$tool","smog.ions.top","smog.ions.gro"));
   }
  }else{
   # for the first test, add a second set of ions.
   $i=1;
   print "\tChecking smog_ions with all-atom model: second set of ions: parameter set $i\n";
   `$exec -f smog.ions.top -g smog.ions.gro -of smog.ions2.top -og smog.ions2.gro -ionnm $PARAMS[$i][0] -ionn  $PARAMS[$i][1] -ionq $PARAMS[$i][2] -ionm $PARAMS[$i][3] -ionC12 $PARAMS[$i][4] -ionC6 $PARAMS[$i][5]   &> output2.$tool`;
   if(-e "smog.ions2.top"){$FAIL{"OUTPUT TOP NAME"}=0;}
   if(-e "smog.ions2.gro"){$FAIL{"OUTPUT GRO NAME"}=0;}
   ($FATAL,$UNINIT)=checkoutput("output.$tool");
 
   $FAIL{"NON-ZERO EXIT"}=$FATAL;
   $FAIL{"UNINITIALIZED VARIABLES"}=$UNINIT;
   $FAIL{"CHECK TOP"}=checktopions("smog.ions.top","smog.ions2.top",$PARAMS[$i][0],$PARAMS[$i][1],$PARAMS[$i][2],$PARAMS[$i][3],$PARAMS[$i][4],$PARAMS[$i][5]);
   ($FAILED,$printbuffer)=failsum(\%FAIL,\@FAILLIST);
   $FAILSUM += $FAILED;
   if($FAILED !=0){
    savefailed("AA.$i",("output.$tool","smog.ions.top","smog.ions.gro","output2.$tool","smog.ions2.top","smog.ions2.gro"));
    print "$printbuffer\n";
   }else{
    clearfiles(("output.$tool","smog.ions.top","smog.ions.gro","output2.$tool","smog.ions2.top","smog.ions2.gro"));
   }
  }
 }

# verify that smog_ion works with the -t flag
 my $tdir="share/templates/SBM_AA";
 my %idefsm;
 my %idefsq;
 my %idefs6;
 my %idefs12;
 my $Nions=0;
 open(IONDEFS,"$tdir/ions.def") or internal_error("can not open $tdir/ions.def");
 while(<IONDEFS>){
  my $LINE=$_;
  chomp($LINE);
  my @B=split (/\s+/,$LINE);
  $idefsm{$B[0]}=$B[1];
  $idefsq{$B[0]}=$B[2];
  $idefs6{$B[0]}=$B[4];
  $idefs12{$B[0]}=$B[3];
  $Nions++;
 }
 if($Nions ==0){
  internal_error("Nothing read from ions.def file.")
 }
 foreach my $IONNAME (keys %idefsm){
  print "\tChecking smog_ions with all-atom model and $IONNAME: parameter set read from $tdir\n";

  %FAIL=resettests(\%FAIL,\@FAILLIST);

  `$exec -f AA.tmp.top -g AA.tmp.gro -ionnm $IONNAME -ionn 100 -t $tdir  &> output.$tool`;
  if(-e "smog.ions.top"){$FAIL{"OUTPUT TOP NAME"}=0;}
  if(-e "smog.ions.gro"){$FAIL{"OUTPUT GRO NAME"}=0;}
  ($FATAL,$UNINIT)=checkoutput("output.$tool");
  $FAIL{"NON-ZERO EXIT"}=$FATAL;
  $FAIL{"UNINITIALIZED VARIABLES"}=$UNINIT;
  $FAIL{"CHECK TOP"}=checktopions("AA.tmp.top","smog.ions.top",$IONNAME,100,$idefsq{$IONNAME},$idefsm{$IONNAME},$idefs12{$IONNAME},$idefs6{$IONNAME});

  ($FAILED,$printbuffer)=failsum(\%FAIL,\@FAILLIST);
  $FAILSUM += $FAILED;
  if($FAILED !=0){
   savefailed("AA.$IONNAME",("output.$tool","smog.ions.top","smog.ions.gro"));
   print "$printbuffer\n";
  }else{
   clearfiles(("output.$tool","smog.ions.top","smog.ions.gro"));
  }
 }
 clearfiles(("AA.tmp.contacts", "AA.tmp.contacts.CG", "AA.tmp.gro" , "AA.tmp.ndx" , "AA.tmp.top"));


# perform checks for CA model protein 
 `smog2 -i $pdbdir/2ci2_v2.pdb -CA -dname CA.tmp > output.smog`;
 ($SMOGFATAL,$smt)=checkoutput("output.smog");
 unless($SMOGFATAL == 0){
  internal_error("SMOG 2 crashed.  Fix SMOG 2 before testing smog_ions.");
 }else{
  clearfiles("output.smog");
 }

 for(my $i=0;$i<=$#PARAMS;$i++){
  print "\tChecking smog_ions with C-alpha model: parameter set $i\n";

  %FAIL=resettests(\%FAIL,\@FAILLIST);

  `$exec -f CA.tmp.top -g CA.tmp.gro -ionnm $PARAMS[$i][0] -ionn  $PARAMS[$i][1] -ionq $PARAMS[$i][2] -ionm $PARAMS[$i][3] -ionC12 $PARAMS[$i][4] -ionC6 $PARAMS[$i][5]   &> output.$tool`;
  ($FAIL{"NON-ZERO EXIT"},$FAIL{"UNINITIALIZED VARIABLES"})=checkoutput("output.$tool");
   if(-e "smog.ions.top"){$FAIL{"OUTPUT TOP NAME"}=0;}
   if(-e "smog.ions.gro"){$FAIL{"OUTPUT GRO NAME"}=0;}
   $FAIL{"CHECK TOP"}=checktopions("CA.tmp.top","smog.ions.top",$PARAMS[$i][0],$PARAMS[$i][1],$PARAMS[$i][2],$PARAMS[$i][3],$PARAMS[$i][4],$PARAMS[$i][5]);

  ($FAILED,$printbuffer)=failsum(\%FAIL,\@FAILLIST);
  $FAILSUM += $FAILED;
  if($FAILED !=0){
   savefailed("CA.$i",("output.$tool","smog.ions.top","smog.ions.gro"));
   print "$printbuffer\n";
  }else{
   clearfiles(("output.$tool","smog.ions.top","smog.ions.gro"));
  }
 }
 clearfiles(("CA.tmp.contacts", "CA.tmp.contacts.CG", "CA.tmp.gro" , "CA.tmp.ndx" , "CA.tmp.top"));
 
 return ($FAILSUM, $printbuffer);

}

sub checktopions
{
 my $error=11;
 my ($file1,$file2,$ionnm,$ionn,$ionq,$ionm,$ionC12,$ionC6)=@_;
 my $string=loadfile($file1);
 my @D=split(/\n/,$string);
 # read in the two top files
 my $N1=0;
 my @FILE1;
 for (my $i=0;$i<=$#D;$i++){
  my ($LINE,$COM)=checkcomment($D[$i]);
  if(hascontent($LINE)){
   $FILE1[$N1]=$LINE;
 #  print "$FILE1[$N1]\n";
   $N1++;
  }
 }
 $#D=-1;
 $string=loadfile($file2);
 @D=split(/\n/,$string);
 my $N2=0;
 my @FILE2;
 for (my $i=0;$i<=$#D;$i++){
  my ($LINE,$COM)=checkcomment($D[$i]);
  if(hascontent($LINE)){
   $FILE2[$N2]=$LINE;
#  print "$FILE1[$N1]\n";
   $N2++;
  }
 }
 $#D=-1;

 # The first difference needs to be the ion listing under atomtypes
 my $ln1=0;
 my $ln2=0;
 until($FILE1[$ln1] ne $FILE2[$ln2]){
  $ln1++;
  $ln2++; 
 } 
 # check that the correct atom type is added
 my @A=split(/\s+/,$FILE2[$ln2]);

 if("$ionnm" eq "$A[0]" ){
  $error--;
 }else{
  print "Wrong ion name.  Expected $ionnm: found $A[0]\n";
 }
 if("$ionq" eq "$A[2]" ){
  $error--;
 }else{
  print "Wrong ion charge.  Expected $ionq: found $A[2]\n";
 }
 if("$ionm" eq "$A[1]" ){
  $error--;
 }else{
  print "Wrong ion mass.  Expected $ionm: found $A[1]\n";
 }
 if("$ionC6" eq "$A[4]" ){
  $error--;
 }else{
  print "Wrong ion C6.  Expected $ionC6: found $A[4]\n";
 }
 if("$ionC12" eq "$A[5]" ){
  $error--;
 }else{
  print "Wrong ion C12.  Expected $ionC12: found $A[5]\n";
 }

 # go to next line, after the difference is found
 $ln2++;

 # find the next difference 
 until($FILE1[$ln1] ne $FILE2[$ln2]){
  $ln1++;
  $ln2++; 
 } 
 # read and save FILE2 info, until the lines match again
 my @diffblock;
 my $NN=0;
 until($FILE1[$ln1] eq $FILE2[$ln2]){
  $diffblock[$NN]=$FILE2[$ln2];
  $ln2++;
  $NN++; 
 } 

 # check the molecultype info
 if ($diffblock[0] eq "$ionnm 1"){
  $error--;
 }else{
  print "Wrong ion molecule type name.  Expected $ionnm 1: found $diffblock[0]\n";
 }
 if($diffblock[1] == "[ atoms ]"){
  $error--;
 }else{
  print "[atoms] line has an issue: Found $diffblock[1]\n";
 }

 if ($diffblock[2] eq "1 $ionnm 1 $ionnm $ionnm 1"){
  $error--;
 }else{
  print "Wrong atoms information.  Expected 1 $ionnm 1 $ionnm $ionnm 1: found $diffblock[2]\n";
 }

 if ($diffblock[3] eq "[ moleculetype ]"){
  $error--;
 }else{
  print "Too many extra lines in the new top file\n";
 }

 # the final diff should be the last line.
 until($FILE1[$ln1] ne $FILE2[$ln2] || $ln1== $N1){
  $ln1++;
  $ln2++; 
 } 

 if($ln1==$N1 && $ln2+1==$N2){
  #made it to the end without something else that is added
  $error--;
 }else{
  print "Too many extra lines in the new top file\n";
 }

 if($FILE2[$ln2] eq "$ionnm $ionn"){
  $error--;
 }else{
  print "Wrong name or number of molecules at the end. Expected $ionnm $ionn: Found $FILE2[$ln2+1]\n";
 }
 if($error<0){
  internal_error("Issue in ions");
 }
return $error;
}


return 1;

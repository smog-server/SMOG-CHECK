package smog_adjust;
use strict;
use Exporter;
use smog_common;

sub check_adjust
{
	my $NFAIL=0;
	my $MESSAGE="";

	`$EXEC_ADJUST -i $PDB_DIR/3PTA.preadjust.pdb -default > adjust.output`;




	return ($NFAIL, $MESSAGE);

}

return 1;

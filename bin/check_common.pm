package check_common;
use strict;
use Exporter;

our @ISA = 'Exporter';
our @EXPORT =
qw(internal_error smogcheck_error failed_message);

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















return 1;

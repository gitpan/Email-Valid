package Email::Valid::NSLookup;

$NSLOOKUP_PAT  = 'preference|serial|expire|mail\s+exchanger';
@PATHS = qw( /usr/bin/nslookup /usr/sbin/nslookup /usr/bin/nslookup );
$DEBUG = 0;

use strict;
use vars qw( @PATHS $PATH $NSLOOKUP_PAT $DEBUG );
use Carp;
use IO::File;

sub _find_binary {
  my $class = shift;

  foreach my $path (@PATHS) {
    return $PATH = $path if -x $path;
  }
  croak 'unable to locate nslookup';  
}

sub lookup {
  my $class = shift;
  my $host  = shift;
  local($/);

  $class->_find_binary unless $PATH;

  if (my $fh = new IO::File '-|') {
    my $response = <$fh>;
    print STDERR $response if $DEBUG;
    close $fh;
    $response =~ /$NSLOOKUP_PAT/io or return undef;
    return 1;
  } else {
    open OLDERR, '>&STDERR' or croak "cannot dup stderr: $!";
    open STDERR, '>&STDOUT' or croak "cannot redirect stderr to stdout: $!";
    exec $PATH, '-query=mx', $host;
    open STDERR, ">&OLDERR";
    croak "unable to execute nslookup '$PATH': $!";
  }                         
}

1;

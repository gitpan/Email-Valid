package Email::Valid;

use strict;
use vars qw( $VERSION $RFC822PAT %AUTOLOAD $AUTOLOAD );
use Carp;
use UNIVERSAL;
use Mail::Address;

$VERSION = '0.07';

%AUTOLOAD = ( nslookup_path => 1, nslookup_failure => 1, mxcheck => 1,
              fudge => 1, debug => 1, fully_qualified => 1,
              special_restrictions => 1, local_rules => 1, 
              fqdn => 1 );   

sub new {
  my $class   = shift;

  $class = ref $class || $class;
  bless my $self = {}, $class;
  $self->_initialize;
  %$self = $self->_rearrange([qw( nslookup_path nslookup_failure
                                  mxcheck fudge debug fully_qualified
                                  special_restrictions local_rules
                                  fqdn )], \@_);
  return $self;
}

sub _initialize {
  my $self = shift;

  $self->{mxcheck}     = 0;
  $self->{fudge}       = 0;
  $self->{fqdn}        = 1;
  $self->{local_rules} = 1;
}            

sub _rearrange {
  my $self = shift;
  my(@names)  = @{ shift() };
  my(@params) = @{ shift() };
  my(%args);

  ref $self ? %args = %$self : _initialize( \%args );
  
  unless ($params[0] =~ /^-/) {
    while(@params) {
      croak 'unexpected number of parameters' unless @names;
      $args{ lc shift @names } = shift @params;
    }
    return %args;
  }

  while(@params) {
    my $param = lc substr(shift @params, 1);
    $args{ $param } = shift @params;
  }

  %args;
}                         

sub rfc822 {
  my $self = shift;
  my %args = $self->_rearrange([qw( address )], \@_);

  my $addr = $args{address} or return undef;
  $addr = $addr->address if UNIVERSAL::isa($addr, 'Mail::Address');

  return($addr =~ m/^$RFC822PAT$/o ? 1 : undef);
}

sub mx {
  my $self = shift;
  my %args = $self->_rearrange([qw( address )], \@_);

  my $addr = $args{address} or return undef;
  $addr = $addr->address if UNIVERSAL::isa($addr, 'Mail::Address');

  my $host = ($addr =~ /^.*@(.*)$/ ? $1 : $addr);
  $host =~ s/\s+//g;

  # REMOVE BRACKETS IF IT'S A DOMAIN-LITERAL
  #   RFC822 3.4.6
  #   Square brackets ("[" and "]") are used to indicate the
  #   presence of a domain-literal, which the appropriate
  #   name-domain is to use directly, bypassing normal
  #   name-resolution mechanisms.
  $host =~ s/(^\[)|(\]$)//g;         

  $host or return undef;

  # CHECK FOR AN A RECORD
  my $mailhost = gethostbyname $host;
  return 1 if defined $mailhost;     

  # CHECK FOR MX RECORD
  require Email::Valid::NSLookup;
  return 2 if Email::Valid::NSLookup->lookup( $host );

  return undef;  
}

sub _fudge {
  my $self = shift;
  my $addr = shift;

  $addr or return undef;

  $addr =~ s/\s+//g if $addr =~ /aol\.com$/i;
  $addr =~ s/,/./g  if $addr =~ /compuserve\.com$/i;
  $addr;
}

# SPECIAL RESTRICTIONS ON A PER-DOMAIN BASIS
sub _local_rules {
  my $self = shift;
  my $addr = shift;

  my($user, $host) = ($addr->user, $addr->host);

  # AOL ADDRESSING CONVENTIONS (according to their autoresponder)
  #   AOL addresses cannot:
  #     - be shorter than 3 or longer than 10 characters
  #     - begin with numerals
  #     - contain periods, underscores, dashes or other punctuation
  #                  
  if ($host =~ /aol\.com/i) {
    return undef unless $user =~ /^[a-z][a-z0-9]{2,9}$/;
  }
  1;  
}

sub address {
  my $self = shift;
  my %args = $self->_rearrange([qw( address fudge special_restrictions
                                    fully_qualified mxcheck nslookup_path
                                    nslookup_failure debug fqdn 
                                    local_rules )], \@_);

  # For backwards compatibility
  $args{fqdn}        ||= $args{fully_qualified};
  $args{local_rules} ||= $args{special_restrictions};

  my $addr = $args{address} or return undef;
  $addr = $addr->address if UNIVERSAL::isa($addr, 'Mail::Address');

  $addr = $self->_fudge( $addr ) if $args{fudge};

  return undef unless $self->rfc822( $addr );

  ($addr) = Mail::Address->parse( $addr );
  return undef unless $addr;

  return undef if $args{local_rules} and not $self->_local_rules( $addr );

  return undef if $args{fqdn} and $addr->host !~ /^.+\..+$/;

  return undef if $args{mxcheck} and not $self->mx( $addr->host );

  return $addr->address; 
}

sub AUTOLOAD {
  my $self = shift;
  my $type = ref($self) || die "$self is not an object";
  my $name = $AUTOLOAD;

  $name =~ s/.*://;
  return if $name eq 'DESTROY';
  die "unknown autoload name '$name'" unless $AUTOLOAD{$name};

  return (@_ ? $self->{$name} = shift : $self->{$name});
}               

# Regular expression built using Jeffrey Friedl's example in
# _Mastering Regular Expressions_ (http://www.ora.com/catalog/regexp/).

$RFC822PAT = <<'EOF';
[\040\t]*(?:\([^\\\x80-\xff\n\015()]*(?:(?:\\[^\x80-\xff]|\([^\\\x80-\
xff\n\015()]*(?:\\[^\x80-\xff][^\\\x80-\xff\n\015()]*)*\))[^\\\x80-\xf
f\n\015()]*)*\)[\040\t]*)*(?:(?:[^(\040)<>@,;:".\\\[\]\000-\037\x80-\x
ff]+(?![^(\040)<>@,;:".\\\[\]\000-\037\x80-\xff])|"[^\\\x80-\xff\n\015
"]*(?:\\[^\x80-\xff][^\\\x80-\xff\n\015"]*)*")[\040\t]*(?:\([^\\\x80-\
xff\n\015()]*(?:(?:\\[^\x80-\xff]|\([^\\\x80-\xff\n\015()]*(?:\\[^\x80
-\xff][^\\\x80-\xff\n\015()]*)*\))[^\\\x80-\xff\n\015()]*)*\)[\040\t]*
)*(?:\.[\040\t]*(?:\([^\\\x80-\xff\n\015()]*(?:(?:\\[^\x80-\xff]|\([^\
\\x80-\xff\n\015()]*(?:\\[^\x80-\xff][^\\\x80-\xff\n\015()]*)*\))[^\\\
x80-\xff\n\015()]*)*\)[\040\t]*)*(?:[^(\040)<>@,;:".\\\[\]\000-\037\x8
0-\xff]+(?![^(\040)<>@,;:".\\\[\]\000-\037\x80-\xff])|"[^\\\x80-\xff\n
\015"]*(?:\\[^\x80-\xff][^\\\x80-\xff\n\015"]*)*")[\040\t]*(?:\([^\\\x
80-\xff\n\015()]*(?:(?:\\[^\x80-\xff]|\([^\\\x80-\xff\n\015()]*(?:\\[^
\x80-\xff][^\\\x80-\xff\n\015()]*)*\))[^\\\x80-\xff\n\015()]*)*\)[\040
\t]*)*)*@[\040\t]*(?:\([^\\\x80-\xff\n\015()]*(?:(?:\\[^\x80-\xff]|\([
^\\\x80-\xff\n\015()]*(?:\\[^\x80-\xff][^\\\x80-\xff\n\015()]*)*\))[^\
\\x80-\xff\n\015()]*)*\)[\040\t]*)*(?:[^(\040)<>@,;:".\\\[\]\000-\037\
x80-\xff]+(?![^(\040)<>@,;:".\\\[\]\000-\037\x80-\xff])|\[(?:[^\\\x80-
\xff\n\015\[\]]|\\[^\x80-\xff])*\])[\040\t]*(?:\([^\\\x80-\xff\n\015()
]*(?:(?:\\[^\x80-\xff]|\([^\\\x80-\xff\n\015()]*(?:\\[^\x80-\xff][^\\\
x80-\xff\n\015()]*)*\))[^\\\x80-\xff\n\015()]*)*\)[\040\t]*)*(?:\.[\04
0\t]*(?:\([^\\\x80-\xff\n\015()]*(?:(?:\\[^\x80-\xff]|\([^\\\x80-\xff\
n\015()]*(?:\\[^\x80-\xff][^\\\x80-\xff\n\015()]*)*\))[^\\\x80-\xff\n\
015()]*)*\)[\040\t]*)*(?:[^(\040)<>@,;:".\\\[\]\000-\037\x80-\xff]+(?!
[^(\040)<>@,;:".\\\[\]\000-\037\x80-\xff])|\[(?:[^\\\x80-\xff\n\015\[\
]]|\\[^\x80-\xff])*\])[\040\t]*(?:\([^\\\x80-\xff\n\015()]*(?:(?:\\[^\
x80-\xff]|\([^\\\x80-\xff\n\015()]*(?:\\[^\x80-\xff][^\\\x80-\xff\n\01
5()]*)*\))[^\\\x80-\xff\n\015()]*)*\)[\040\t]*)*)*|(?:[^(\040)<>@,;:".
\\\[\]\000-\037\x80-\xff]+(?![^(\040)<>@,;:".\\\[\]\000-\037\x80-\xff]
)|"[^\\\x80-\xff\n\015"]*(?:\\[^\x80-\xff][^\\\x80-\xff\n\015"]*)*")[^
()<>@,;:".\\\[\]\x80-\xff\000-\010\012-\037]*(?:(?:\([^\\\x80-\xff\n\0
15()]*(?:(?:\\[^\x80-\xff]|\([^\\\x80-\xff\n\015()]*(?:\\[^\x80-\xff][
^\\\x80-\xff\n\015()]*)*\))[^\\\x80-\xff\n\015()]*)*\)|"[^\\\x80-\xff\
n\015"]*(?:\\[^\x80-\xff][^\\\x80-\xff\n\015"]*)*")[^()<>@,;:".\\\[\]\
x80-\xff\000-\010\012-\037]*)*<[\040\t]*(?:\([^\\\x80-\xff\n\015()]*(?
:(?:\\[^\x80-\xff]|\([^\\\x80-\xff\n\015()]*(?:\\[^\x80-\xff][^\\\x80-
\xff\n\015()]*)*\))[^\\\x80-\xff\n\015()]*)*\)[\040\t]*)*(?:@[\040\t]*
(?:\([^\\\x80-\xff\n\015()]*(?:(?:\\[^\x80-\xff]|\([^\\\x80-\xff\n\015
()]*(?:\\[^\x80-\xff][^\\\x80-\xff\n\015()]*)*\))[^\\\x80-\xff\n\015()
]*)*\)[\040\t]*)*(?:[^(\040)<>@,;:".\\\[\]\000-\037\x80-\xff]+(?![^(\0
40)<>@,;:".\\\[\]\000-\037\x80-\xff])|\[(?:[^\\\x80-\xff\n\015\[\]]|\\
[^\x80-\xff])*\])[\040\t]*(?:\([^\\\x80-\xff\n\015()]*(?:(?:\\[^\x80-\
xff]|\([^\\\x80-\xff\n\015()]*(?:\\[^\x80-\xff][^\\\x80-\xff\n\015()]*
)*\))[^\\\x80-\xff\n\015()]*)*\)[\040\t]*)*(?:\.[\040\t]*(?:\([^\\\x80
-\xff\n\015()]*(?:(?:\\[^\x80-\xff]|\([^\\\x80-\xff\n\015()]*(?:\\[^\x
80-\xff][^\\\x80-\xff\n\015()]*)*\))[^\\\x80-\xff\n\015()]*)*\)[\040\t
]*)*(?:[^(\040)<>@,;:".\\\[\]\000-\037\x80-\xff]+(?![^(\040)<>@,;:".\\
\[\]\000-\037\x80-\xff])|\[(?:[^\\\x80-\xff\n\015\[\]]|\\[^\x80-\xff])
*\])[\040\t]*(?:\([^\\\x80-\xff\n\015()]*(?:(?:\\[^\x80-\xff]|\([^\\\x
80-\xff\n\015()]*(?:\\[^\x80-\xff][^\\\x80-\xff\n\015()]*)*\))[^\\\x80
-\xff\n\015()]*)*\)[\040\t]*)*)*(?:,[\040\t]*(?:\([^\\\x80-\xff\n\015(
)]*(?:(?:\\[^\x80-\xff]|\([^\\\x80-\xff\n\015()]*(?:\\[^\x80-\xff][^\\
\x80-\xff\n\015()]*)*\))[^\\\x80-\xff\n\015()]*)*\)[\040\t]*)*@[\040\t
]*(?:\([^\\\x80-\xff\n\015()]*(?:(?:\\[^\x80-\xff]|\([^\\\x80-\xff\n\0
15()]*(?:\\[^\x80-\xff][^\\\x80-\xff\n\015()]*)*\))[^\\\x80-\xff\n\015
()]*)*\)[\040\t]*)*(?:[^(\040)<>@,;:".\\\[\]\000-\037\x80-\xff]+(?![^(
\040)<>@,;:".\\\[\]\000-\037\x80-\xff])|\[(?:[^\\\x80-\xff\n\015\[\]]|
\\[^\x80-\xff])*\])[\040\t]*(?:\([^\\\x80-\xff\n\015()]*(?:(?:\\[^\x80
-\xff]|\([^\\\x80-\xff\n\015()]*(?:\\[^\x80-\xff][^\\\x80-\xff\n\015()
]*)*\))[^\\\x80-\xff\n\015()]*)*\)[\040\t]*)*(?:\.[\040\t]*(?:\([^\\\x
80-\xff\n\015()]*(?:(?:\\[^\x80-\xff]|\([^\\\x80-\xff\n\015()]*(?:\\[^
\x80-\xff][^\\\x80-\xff\n\015()]*)*\))[^\\\x80-\xff\n\015()]*)*\)[\040
\t]*)*(?:[^(\040)<>@,;:".\\\[\]\000-\037\x80-\xff]+(?![^(\040)<>@,;:".
\\\[\]\000-\037\x80-\xff])|\[(?:[^\\\x80-\xff\n\015\[\]]|\\[^\x80-\xff
])*\])[\040\t]*(?:\([^\\\x80-\xff\n\015()]*(?:(?:\\[^\x80-\xff]|\([^\\
\x80-\xff\n\015()]*(?:\\[^\x80-\xff][^\\\x80-\xff\n\015()]*)*\))[^\\\x
80-\xff\n\015()]*)*\)[\040\t]*)*)*)*:[\040\t]*(?:\([^\\\x80-\xff\n\015
()]*(?:(?:\\[^\x80-\xff]|\([^\\\x80-\xff\n\015()]*(?:\\[^\x80-\xff][^\
\\x80-\xff\n\015()]*)*\))[^\\\x80-\xff\n\015()]*)*\)[\040\t]*)*)?(?:[^
(\040)<>@,;:".\\\[\]\000-\037\x80-\xff]+(?![^(\040)<>@,;:".\\\[\]\000-
\037\x80-\xff])|"[^\\\x80-\xff\n\015"]*(?:\\[^\x80-\xff][^\\\x80-\xff\
n\015"]*)*")[\040\t]*(?:\([^\\\x80-\xff\n\015()]*(?:(?:\\[^\x80-\xff]|
\([^\\\x80-\xff\n\015()]*(?:\\[^\x80-\xff][^\\\x80-\xff\n\015()]*)*\))
[^\\\x80-\xff\n\015()]*)*\)[\040\t]*)*(?:\.[\040\t]*(?:\([^\\\x80-\xff
\n\015()]*(?:(?:\\[^\x80-\xff]|\([^\\\x80-\xff\n\015()]*(?:\\[^\x80-\x
ff][^\\\x80-\xff\n\015()]*)*\))[^\\\x80-\xff\n\015()]*)*\)[\040\t]*)*(
?:[^(\040)<>@,;:".\\\[\]\000-\037\x80-\xff]+(?![^(\040)<>@,;:".\\\[\]\
000-\037\x80-\xff])|"[^\\\x80-\xff\n\015"]*(?:\\[^\x80-\xff][^\\\x80-\
xff\n\015"]*)*")[\040\t]*(?:\([^\\\x80-\xff\n\015()]*(?:(?:\\[^\x80-\x
ff]|\([^\\\x80-\xff\n\015()]*(?:\\[^\x80-\xff][^\\\x80-\xff\n\015()]*)
*\))[^\\\x80-\xff\n\015()]*)*\)[\040\t]*)*)*@[\040\t]*(?:\([^\\\x80-\x
ff\n\015()]*(?:(?:\\[^\x80-\xff]|\([^\\\x80-\xff\n\015()]*(?:\\[^\x80-
\xff][^\\\x80-\xff\n\015()]*)*\))[^\\\x80-\xff\n\015()]*)*\)[\040\t]*)
*(?:[^(\040)<>@,;:".\\\[\]\000-\037\x80-\xff]+(?![^(\040)<>@,;:".\\\[\
]\000-\037\x80-\xff])|\[(?:[^\\\x80-\xff\n\015\[\]]|\\[^\x80-\xff])*\]
)[\040\t]*(?:\([^\\\x80-\xff\n\015()]*(?:(?:\\[^\x80-\xff]|\([^\\\x80-
\xff\n\015()]*(?:\\[^\x80-\xff][^\\\x80-\xff\n\015()]*)*\))[^\\\x80-\x
ff\n\015()]*)*\)[\040\t]*)*(?:\.[\040\t]*(?:\([^\\\x80-\xff\n\015()]*(
?:(?:\\[^\x80-\xff]|\([^\\\x80-\xff\n\015()]*(?:\\[^\x80-\xff][^\\\x80
-\xff\n\015()]*)*\))[^\\\x80-\xff\n\015()]*)*\)[\040\t]*)*(?:[^(\040)<
>@,;:".\\\[\]\000-\037\x80-\xff]+(?![^(\040)<>@,;:".\\\[\]\000-\037\x8
0-\xff])|\[(?:[^\\\x80-\xff\n\015\[\]]|\\[^\x80-\xff])*\])[\040\t]*(?:
\([^\\\x80-\xff\n\015()]*(?:(?:\\[^\x80-\xff]|\([^\\\x80-\xff\n\015()]
*(?:\\[^\x80-\xff][^\\\x80-\xff\n\015()]*)*\))[^\\\x80-\xff\n\015()]*)
*\)[\040\t]*)*)*>)
EOF

$RFC822PAT =~ s/\n//g;

1;

__END__

=head1 NAME

Email::Valid - Check validity of Internet e-mail addresses 

=head1 SYNOPSIS

  use Email::Valid;
  print (Email::Valid->address('maurice@hevanet.com') ? 'yes' : 'no');

=head1 DESCRIPTION

This module determines whether an e-mail address is well-formed, and
optionally, whether a mail host exists for the domain.

Please note that there is no way to definitely determine whether an
address is deliverable without attempting delivery (for details, see
perlfaq 9).

=head1 PREREQUISITES

Your system must have the nslookup utility in order to perform DNS checks.

=head1 METHODS

  Every method which accepts an <ADDRESS> parameter may
  be passed either a string or an instance of the Mail::Address
  class.

=over 4

=item new ( [PARAMS] )

This method is used to construct an Email::Valid object.
It accepts an optional list of named parameters to
control the behavior of the object at instantiation.

The following named parameters are allowed.  See the
individual methods below of details.

 -mxcheck
 -fudge
 -fqdn
 -local_rules

=item mx ( <ADDRESS>|<DOMAIN> )

This method accepts an e-mail address or domain name, and determines
whether a DNS records (A or MX record) exists for the domain.

The method returns true if a record is found, or undef if no record
is found or an error is encountered.

DNS queries are currently performed using the 'nslookup' utility.  

=item rfc822 ( <ADDRESS> )

This method determines whether an address conforms to the RFC822
specification (except for nested comments).  It returns true if it
conforms, and undef if not.

=item fudge ( <TRUE>|<FALSE> )

Specifies whether calls to address() should attempt to correct
common addressing errors.  Currently, this results in the removal of
spaces in AOL addresses, and the conversion of commas to periods in
Compuserve addresses.  The default is false.

=item fqdn ( <TRUE>|<FALSE> )

Species whether addresses passed to address() must contain a fully
qualified domain name (FQDN).  The default is true.

=item local_rules ( <TRUE>|<FALSE> )

Specifies whether addresses passed to address() should be tested
for domain specific restrictions.  Currently, this is limited to
certain AOL restrictions that I'm aware of.  The default is true.

=item mxcheck ( <TRUE>|<FALSE> )

Specifies whether addresses passed to address() should be checked
for a valid DNS entry.  The default is false.

=item address ( <ADDRESS> )

This is the primary method, which determines whether an e-mail 
address is valid.  It's behavior is modified by the values of
mxcheck(), local_rules(), fqdn(), and fudge().  If the address passes
all checks, the (possibly modified) address is returned.  If the
address does not pass a check, the undefined value is returned.

=back

=head1 EXAMPLES

Let's see if the address 'maurice@hevanet.com' conforms to the
RFC822 specification:

  print (Email::Valid->address('maurice@hevanet.com') ? 'yes' : 'no');

Additionally, let's make sure there's a mail host for it:

  print (Email::Valid->address( -address => 'maurice@hevanet.com',
                                -mxcheck => 1 ) ? 'yes' : 'no');

Let's see an example of how the address may be modified:

  $addr = Email::Valid->address('Alfred Neuman <Neuman @ foo.bar>');
  print "$addr\n"; # prints Neuman@foo.bar

=head1 BUGS

Other methods of performing DNS queries should be implemented, to increase
portability.

=head1 AUTHOR

Copyright (C) 1998 Maurice Aubrey E<lt>maurice@hevanet.comE<gt>. 

This module is free software; you may redistribute it and/or
modify it under the same terms as Perl itself.

Significant portions of this module are based on the ckaddr program
written by Tom Christiansen and the RFC822 address pattern developed
by Jeffrey Friedl.  Neither were involved in the construction of this 
module; all errors are mine.

=head1 SEE ALSO

perl(1).

=cut

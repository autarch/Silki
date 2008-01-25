package Silk::Config;

use strict;
use warnings;

use Net::Interface;
use Socket qw( AF_INET );
use Sys::Hostname qw( hostname );

use Moose;
use MooseX::ClassAttribute;

class_has 'SystemHostname' =>
    ( is      => 'ro',
      isa     => 'Str',
      lazy    => 1,
      default => \&_DetermineSystemHostname,
    );

sub _DetermineSystemHostname
{
    for my $name ( hostname(),
                   map { scalar gethostbyaddr $_->address(), AF_INET }
                   Net::Interface->interfaces()
                 )
    {
        return $name if $name =~ /\.[^.]+$/;
    }

    die 'Cannot determine system hostname.';
}

__PACKAGE__->meta()->make_immutable();
no Moose;
no MooseX::ClassAttribute;

1;

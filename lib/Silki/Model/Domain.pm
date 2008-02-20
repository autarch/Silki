package Silki::Model::Domain;

use strict;
use warnings;

use Silki::Config;
use Silki::Model::Schema;
use URI;

use Fey::ORM::Table;
use MooseX::ClassAttribute;

has_table( Silki::Model::Schema->Schema()->table('Domain') );


class_has 'DefaultDomain' =>
    ( is      => 'ro',
      isa     => __PACKAGE__,
      lazy    => 1,
      default => sub { __PACKAGE__->_FindOrCreateDefaultDomain() },
    );


sub base_uri
{
    my $self = shift;

    my $uri = URI->new();

    $uri->scheme( $self->requires_ssl() ? 'https' : 'http' );
    $uri->host( $self->hostname() );
    $uri->path( $self->path_prefix() );

    return $uri;
}

sub EnsureRequiredDomainsExist
{
    my $class = shift;

    $class->_FindOrCreateDefaultDomain();
}

sub _FindOrCreateDefaultDomain
{
    my $class = shift;

    my $hostname = Silki::Config->SystemHostname();

    my $domain = $class->new( hostname => $hostname );
    return $domain if $domain;

    return $class->insert( hostname => $hostname );
}


no Fey::ORM::Table;
no Moose;
no MooseX::ClassAttribute;

__PACKAGE__->meta()->make_immutable();


1;

__END__



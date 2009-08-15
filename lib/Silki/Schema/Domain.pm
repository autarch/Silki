package Silki::Schema::Domain;

use strict;
use warnings;

use Silki::Config;
use Silki::Schema;
use Silki::Types qw( Bool HashRef Str );
use URI;

use Fey::ORM::Table;
use MooseX::ClassAttribute;
use MooseX::Params::Validate qw( validated_hash );

with 'Silki::Role::Schema::URIMaker';

has_policy 'Silki::Schema::Policy';

has_table( Silki::Schema->Schema()->table('Domain') );

class_has 'DefaultDomain' =>
    ( is      => 'ro',
      isa     => __PACKAGE__,
      lazy    => 1,
      default => sub { __PACKAGE__->_FindOrCreateDefaultDomain() },
    );

has uri_params =>
    ( is       => 'ro',
      isa      => HashRef,
      lazy     => 1,
      builder  => '_build_uri_params',
      init_arg => undef,
    );

sub _base_uri_path
{
    return q{};
}

sub EnsureRequiredDomainsExist
{
    my $class = shift;

    $class->_FindOrCreateDefaultDomain();
}

sub _FindOrCreateDefaultDomain
{
    my $class = shift;

    my $hostname = Silki::Config->new()->system_hostname();

    my $domain = $class->new( web_hostname => $hostname );
    return $domain if $domain;

    return $class->insert( web_hostname   => $hostname,
                           email_hostname => $hostname,
                         );
}

sub domain { $_[0] }

sub _build_uri_params
{
    my $self = shift;

    return { scheme => ( $self->requires_ssl() ? 'https' : 'http' ),
             host   => $self->web_hostname(),
           };
}

sub application_uri
{
    my $self = shift;
    my %p    = validated_hash( \@_,
                               path      => { isa => Str, optional => 1 },
                               fragment  => { isa => Str, optional => 1 },
                               query     => { isa => HashRef, default => {} },
                               with_host => { isa => Bool, default => 0 },
                             );

    return $self->_make_uri(%p);
}

no Fey::ORM::Table;
no Moose;
no MooseX::ClassAttribute;

__PACKAGE__->meta()->make_immutable();


1;

__END__



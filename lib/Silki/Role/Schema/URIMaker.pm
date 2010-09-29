package Silki::Role::Schema::URIMaker;

use strict;
use warnings;
use namespace::autoclean;

use MooseX::Params::Validate qw( validate );
use Silki::Types qw( Bool HashRef Int Str );
use Silki::Util qw( string_is_empty );
use Silki::URI qw( dynamic_uri );

use Moose::Role;

#requires_attr_or_method (??) 'domain';

requires '_base_uri_path';

sub uri {
    # MX::P::V doesn't handle class methods
    my $self = shift;

    my %p = validate(
        \@_,
        view      => { isa => Str,     optional => 1 },
        fragment  => { isa => Str,     optional => 1 },
        query     => { isa => HashRef, default  => {} },
        host      => { isa => Str,     optional => 1 },
        port      => { isa => Int,     optional => 1 },
        with_host => { isa => Bool,    default  => 0 },
    );

    my $path = $self->_base_uri_path();
    unless ( string_is_empty( $p{view} ) ) {
        $path .= q{/} unless $path =~ m{/$};
        $path .= $p{view};
    }

    delete $p{view};

    $self->_make_uri(
        path => $path,
        %p,
    );
}

sub _make_uri {
    my $self = shift;
    my %p    = @_;

    delete $p{fragment}
        if string_is_empty( $p{fragment} );

    return dynamic_uri(
        $self->_host_params_for_uri( delete $p{with_host} ),
        %p,
    );
}

sub _host_params_for_uri {
    my $self = shift;

    return unless $_[0];

    return (
        %{ $self->domain()->uri_params() },
        (
            $ENV{SERVER_PORT}
            ? ( port => $ENV{SERVER_PORT} )
            : ()
        )
    );
}

1;

# ABSTRACT: Adds an $object->uri() method

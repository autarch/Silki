package Silki::Action::REST;

use strict;
use warnings;
use namespace::autoclean;

use Moose;

extends 'Catalyst::Action::REST';

override dispatch => sub {
    my $self = shift;
    my $c    = shift;

    if ( $c->request()->looks_like_browser()
        && uc $c->request()->method() eq 'GET' ) {
        my $controller = $self->class();
        my $method     = $self->name() . '_GET_html';

        if ( $controller->can($method) ) {
            $c->execute( $self->class, $self, @{ $c->req->args } );

            return $controller->$method( $c, @{ $c->request()->args() } );
        }
    }

    return super();
};

# Intentionally not immutable. Catalyst should take care of this for us, I
# think.

1;

# ABSTRACT: Extends dispatch to add get_FOO_html

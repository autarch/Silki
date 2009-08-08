package Silki::Controller::Base;

use strict;
use warnings;

use Silki::Config;
use Silki::JSON;
use Silki::Web::CSS;
use Silki::Web::Javascript;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST' }

sub begin : Private
{
    my $self = shift;
    my $c    = shift;

    Silki::Schema->ClearObjectCaches();

#    $self->_require_authen($c)
#        if $self->_uri_requires_authen( $c->request()->uri() );

    return unless $c->request()->looks_like_browser();

    my $config = Silki::Config->new();

    unless ( $config->is_production() || $config->is_profiling() )
    {
        $_->new()->create_single_file()
            for qw( Silki::Web::CSS Silki::Web::Javascript );
    }

    return 1;
}

sub _uri_requires_authen
{
    my $self = shift;
    my $uri  = shift;

    return 0
        if $uri->path() =~ m{^/user/(?:login_form|forgot_password_form|authentication)};

    return 0 if $uri->path() =~ m{^/(?:die|robots\.txt|exit)};

#    return 1;
}

sub end : Private
{
    my $self = shift;
    my $c    = shift;

    return $self->next::method($c)
        if $c->stash()->{rest};

    if ( ( ! $c->response()->status()
           || $c->response()->status() == 200 )
         && ! $c->response()->body()
         && ! @{ $c->error() || [] } )
    {
        $c->forward( $c->view() );
    }

    return;
}

sub _set_entity
{
    my $self   = shift;
    my $c      = shift;
    my $entity = shift;

    $c->response()->body( Silki::JSON->Encode($entity) );

    return 1;
}

sub _require_authen
{
    my $self = shift;
    my $c    = shift;

    my $user = $c->user();

    return if $user;

    $c->redirect_and_detach( '/user/login_form' );
}

no Moose;

__PACKAGE__->meta()->make_immutable();

1;

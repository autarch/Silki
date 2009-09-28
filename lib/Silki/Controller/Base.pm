package Silki::Controller::Base;

use strict;
use warnings;

use Carp qw( croak );
use Silki::Config;
use Silki::JSON;
use Silki::Web::CSS;
use Silki::Web::Javascript;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST' }

sub begin : Private {
    my $self = shift;
    my $c    = shift;

    Silki::Schema->ClearObjectCaches();

    #    $self->_require_authen($c)
    #        if $self->_uri_requires_authen( $c->request()->uri() );

    return unless $c->request()->looks_like_browser();

    my $config = Silki::Config->new();

    unless ( $config->is_production() || $config->is_profiling() ) {
        $_->new()->create_single_file()
            for qw( Silki::Web::CSS Silki::Web::Javascript );
    }

    Silki::I18N->SetLanguage();

    $c->add_tab(
        {
            uri     => $c->domain()->uri(),
            label   => $c->loc('Home'),
            tooltip => q{},
        }
    );

    return 1;
}

sub end : Private {
    my $self = shift;
    my $c    = shift;

    return $self->next::method($c)
        if $c->stash()->{rest};

    if (   ( !$c->response()->status() || $c->response()->status() == 200 )
        && !$c->response()->body()
        && !@{ $c->error() || [] } ) {
        $c->forward( $c->view() );
    }

    return;
}

sub _set_entity {
    my $self   = shift;
    my $c      = shift;
    my $entity = shift;

    $c->response()->body( Silki::JSON->Encode($entity) );

    return 1;
}

my %MethodPermission = (
    GET  => 'Read',
    POST => 'Edit',
    PUT  => 'Edit',
);

sub _require_permission_for_wiki {
    my $self = shift;
    my $c    = shift;
    my $wiki = shift;
    my $perm = shift;

    $perm ||= $MethodPermission{ uc $c->request()->method() };

    croak 'No permission specified in call to _require_permission_for_wiki'
        unless $perm;

    my $user = $c->user();

    return
        if $user->has_permission_in_wiki(
        wiki       => $wiki,
        permission => Silki::Schema::Permission->$perm(),
        );

    my $perms = $wiki->permissions();

    if ( $user->is_guest() ) {
        if ( $perms->{Authenticated}{$perm} ) {
            $c->session_object()->add_message(
                $c->loc(
                    'This wiki requires you to log in to perform this action.'
                )
            );
        }
        else {
            $c->session_object()->add_message(
                $c->loc(
                    'This wiki requires you to be a member to perform this action.'
                )
            );
        }

        $c->redirect_and_detach('/user/login_form');
    }
    else {
        $c->session_object()->add_message(
            $c->loc(
                'This wiki requires you to be a member to perform this action.'
            )
        );

        my $role = $user->role_in_wiki($wiki);

        my $uri;
        if ( $perms->{$role}{Read} ) {
            $uri
                = $c->stash()->{page}
                ? $c->stash()->{page}->uri()
                : $wiki->uri();
        }
        else {
            $uri = $c->domain()->uri();
        }

        $c->redirect_and_detach($uri);
    }

}

no Moose;

__PACKAGE__->meta()->make_immutable();

1;

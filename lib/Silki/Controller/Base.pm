package Silki::Controller::Base;

use strict;
use warnings;

use autodie;
use Carp qw( croak );
use Silki::Config;
use Silki::I18N qw( loc );
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

    my $user = $c->user();
    my @langs = $user->is_system_user() ? () : $user->locale_code();

    Silki::I18N->SetLanguage(@langs);

    $c->add_tab(
        {
            uri     => $c->domain()->uri(),
            label   => loc('Home'),
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

    # Catalyst::Plugin::XSendfile seems to be designed to only work with
    # Lighthttpd, and deletes any file over 16kb, which we don't want to do. I
    # should probably patch it at some point.
    if ( my $file = $c->response()->header('X-Sendfile') ) {
        my ($engine) = ( ref $c->engine() ) =~ /^Catalyst::Engine::(.+)$/;

        if ( $engine =~ /^HTTP/ ) {
            if ( -f $file ) {
                open my $fh, '<', $file;
                $c->response()->body($fh);
            }
            else {
                $c->log()->error( "X-sendfile pointed at nonexistent file - $file\n" );
                $c->response()->status(404);
            }

            return;
        }
    }

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

    $c->response()->content_type('application/json');
    $c->response()->body( Silki::JSON->Encode($entity) );

    return 1;
}

my %MethodPermission = (
    GET    => 'Read',
    POST   => 'Edit',
    PUT    => 'Edit',
    DELETE => 'Delete',
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
                loc(
                    'You must login to to perform this action in the %1 wiki.',
                    $wiki->title(),
                )
            );
        }
        else {
            $c->session_object()->add_message(
                loc(
                    'You must be a member of the %1 wiki to perform this action.',
                    $wiki->title()
                )
            );
        }

        $c->redirect_and_detach('/user/login_form');
    }
    else {
        $c->session_object()->add_message(
            loc(
                'You must be a member of the %1 wiki to perform this action.',
                $wiki->title()
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

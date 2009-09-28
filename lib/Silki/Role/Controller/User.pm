package Silki::Role::Controller::User;

use strict;
use warnings;

use Moose::Role -traits => 'MooseX::MethodAttributes::Role::Meta::Role';

requires qw( _set_user _make_user_uri );

after '_set_user' => sub {
    my $self    = shift;
    my $c       = shift;
    my $user_id = shift;

    my $user;

    if ( $user_id eq 'guest' ) {
        $user = Silki::Schema::User->GuestUser();
    }
    else {
        $user = Silki::Schema::User->new( user_id => $user_id );
    }

    $c->redirect_and_detach( $c->domain()->uri( with_host => 1 ) )
        unless $user;

    my $wiki = $c->stash()->{wiki};

    my %profile
        = $c->user()->user_id() == $user->user_id()
        ? (
        label   => $c->loc('Your profile'),
        tooltip => $c->loc('View details about your profile'),
        )
        : (
        label   => $user->best_name(),
        tooltip => $c->loc( 'Information about %1', $user->best_name() ),
        );

    $c->add_tab(
        {
            uri => $self->_make_user_uri( $c, $user ),
            id  => 'profile',
            %profile,
        }
    );

    if ( $c->user()->can_edit_user($user) ) {
        my %prefs
            = $c->user()->user_id() == $user->user_id()
            ? (
            label   => $c->loc('Your preferences'),
            tooltip => $c->loc('Set your preferences'),
            )
            : (
            label   => $c->loc( 'Preferences for %1', $user->best_name() ),
            tooltip => $c->loc(
                'View and change preferences for %1', $user->best_name()
            ),
            );

        $c->add_tab(
            {
                uri => $self->_make_user_uri( $c, $user, 'preferences_form' ),
                id  => 'preferences',
                %prefs,
            }
        );
    }

    $c->stash()->{user} = $user;
};

sub user : Chained('_set_user') : PathPart('') : Args(0) :
    ActionClass('+Silki::Action::REST') {
}

sub user_GET_html {
    my $self = shift;
    my $c    = shift;

    $c->tab_by_id('profile')->set_is_selected(1);

    my $user = $c->stash()->{user};

    unless ( $user->is_system_user() ) {
        if ( $user->user_id() == $c->user()->user_id() ) {
            $c->stash()->{user_wikis} = $user->all_wikis()
                if $user->all_wiki_count();
        }
        elsif ( !$c->user()->is_system_user() ) {
            $c->stash()->{shared_wikis}
                = $user->wikis_shared_with( $c->user() );
        }
    }

    $c->stash()->{template} = '/user/profile';
}

sub user_PUT {
    my $self = shift;
    my $c    = shift;

    my $user = $c->stash()->{user};

    $c->redirect_and_detach( $self->_make_user_uri( $c, $user ) )
        unless $c->user()->can_edit_user($user);

    my %update = $c->request()->user_params();

    if ( defined $update{password} ) {
        unless ( defined $update{password2}
            && $update{password} eq $update{password2} ) {
            my @e = {
                field => 'password',
                message =>
                    $c->loc('The two passwords you provided did not match'),
            };

            $self->_user_update_error( $c, \@e, \%update );
        }
    }

    eval { $user->update(%update) };

    if ( my $e = $@ ) {
        $self->_user_update_error( $c, $e, \%update );
    }

    my $message
        = $user->user_id() == $c->user()->user_id()
        ? $c->loc('Your preferences have been updated.')
        : $c->loc(
        'Preferences for ' . $user->best_name() . ' have been updated.' );

    $c->session_object()->add_message($message);

    $c->redirect_and_detach( $self->_make_user_uri( $c, $user ) );
}

sub _user_update_error {
    my $self      = shift;
    my $c         = shift;
    my $errors    = shift;
    my $form_data = shift;

    delete @{$form_data}{qw( password password2 )};

    $c->redirect_with_error(
        error => $errors,
        uri   => $self->_make_user_uri(
            $c, $c->stash()->{user}, 'preferences_form'
        ),
        form_data => $form_data,
    );
}

sub preferences_form : Chained('_set_user') : PathPart('preferences_form') :
    Args(0) {
    my $self = shift;
    my $c    = shift;

    my $user = $c->stash()->{user};

    $c->redirect_and_detach( $self->_make_user_uri( $c, $user ) )
        unless $c->user()->can_edit_user($user);

    $c->tab_by_id('preferences')->set_is_selected(1);

    $c->stash()->{template} = '/user/preferences_form';
}

no Moose::Role;

1;


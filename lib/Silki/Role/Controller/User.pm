package Silki::Role::Controller::User;

use strict;
use warnings;

use Silki::I18N qw( loc );

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
        label   => loc('Your profile'),
        tooltip => loc('View details about your profile'),
        )
        : (
        label   => $user->best_name(),
        tooltip => loc( 'Information about %1', $user->best_name() ),
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
            label   => loc('Your preferences'),
            tooltip => loc('Set your preferences'),
            )
            : (
            label   => loc( 'Preferences for %1', $user->best_name() ),
            tooltip => loc(
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

sub user : Chained('_set_user') : PathPart('') : Args(0) : ActionClass('+Silki::Action::REST') {
}

sub user_GET_html {
    my $self = shift;
    my $c    = shift;

    ( $c->tabs() )[0]->set_is_selected(1);

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

    my $can_edit = 0;
    my $key = $c->request()->params()->{activation_key};
    if ($key) {
        $can_edit
            = $user->requires_activation() && $key eq $user->activation_key();
    }
    else {
        $can_edit = $c->user()->can_edit_user($user);
    }

    $c->redirect_and_detach( $self->_make_user_uri( $c, $user ) )
        unless $can_edit;

    my %update = $c->request()->user_params();
    $update{activation_key} = undef
        if defined $key;
    $update{preserve_password} = 1;

    my @errors = $self->_check_passwords_match(\%update);

    unless (@errors) {
        eval { $user->update(%update) };

        my $e = $@;
        die $e if $e && ! ref $e;

        push @errors, @{ $e->errors() } if $e;
    }

    $self->_user_update_error( $c, \@errors, \%update )
        if @errors;

    $c->set_authen_cookie( value => { user_id => $user->user_id() } );

    my $message
        = $key ? loc(
        'Your account has been activated. Welcome to the site, %1',
        $user->best_name()
        )
        : $user->user_id() == $c->user()->user_id()
        ? loc('Your preferences have been updated.')
        : loc(
        'Preferences for ' . $user->best_name() . ' have been updated.' );

    $c->session_object()->add_message($message);

    $c->redirect_and_detach( $self->_make_user_uri( $c, $user ) );
}

sub _check_passwords_match {
    my $self   = shift;
    my $params = shift;

    return unless defined $params->{password};

    my $pw2 = delete $params->{password2};
    return
        if defined $pw2 && $params->{password} eq $pw2;

    # Deleting both passwords ensures that any update we attempt after this
    # will fail, unless the user also provided an openid, in which case we
    # might as well let it succeed.
    delete @{$params}{qw( password password2 )};

    return {
        field => 'password',
        message =>
            loc('The two passwords you provided did not match'),
    };
}

sub _user_update_error {
    my $self      = shift;
    my $c         = shift;
    my $errors    = shift;
    my $form_data = shift;

    delete @{$form_data}{qw( password password2 )};

    my $uri
        = $c->request()->params()->{activation_key}
        ? $c->stash()->{user}->activation_uri( view => 'preferences_form' )
        : $self->_make_user_uri(
        $c,
        $c->stash()->{user},
        'preferences_form',
        );

    $c->redirect_with_error(
        error => $errors,
        uri   => $uri,
        form_data => $form_data,
    );
}

sub preferences_form : Chained('_set_user') : PathPart('preferences_form') : Args(0) {
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


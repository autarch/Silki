package Silki::Controller::User;

use strict;
use warnings;

use Silki::I18N qw( loc );
use Silki::Schema::TimeZone;
use Silki::Schema::User;
use Silki::Util qw( string_is_empty );

use Moose;

BEGIN { extends 'Silki::Controller::Base' }

with 'Silki::Role::Controller::User';

sub _set_user : Chained('/') : PathPart('user') : CaptureArgs(1) {
}

sub _make_user_uri {
    my $self = shift;
    my $c    = shift;
    my $user = shift;
    my $view = shift || q{};

    return $user->uri( view => $view );
}

sub wikis  : Chained('_set_user') : PathPart('wikis') : Args(0) : ActionClass('+Silki::Action::REST') {
}

sub wikis_GET {
    my $self = shift;
    my $c    = shift;

    my $user = $c->stash()->{user};

    my $wikis = $user->all_wikis();

    my @entity = map {
        {
            wiki_id    => $_->wiki_id(),
            title      => $_->title(),
            short_name => $_->short_name(),
        }
    } $wikis->all();

    return $self->status_ok( $c, entity => \@entity );
}

sub login_form : Local {
    my $self = shift;
    my $c    = shift;

    $c->stash()->{template} = '/user/login_form';
}

sub authentication : Local : ActionClass('+Silki::Action::REST') {
}

sub authentication_GET_html {
    my $self = shift;
    my $c    = shift;

    my $method = $c->request()->param('x-tunneled-method');

    if ( $method && $method eq 'DELETE' ) {
        $self->authentication_DELETE($c);
        return;
    }
    else {
        $c->redirect_and_detach(
            $c->domain()->application_uri( path => '/user/login_form' ) );
    }
}

sub authentication_POST {
    my $self = shift;
    my $c    = shift;

    my $username = $c->request()->params->{username};
    my $pw       = $c->request()->params->{password};

    my @errors;

    push @errors,
        {
        field   => 'password',
        message => $c->loc('You must provide a password.')
        }
        if string_is_empty($pw);

    my $user;
    unless (@errors) {
        $user = Silki::Schema::User->new(
            username => $username,
            password => $pw,
        );

        push @errors,
            $c->loc('The username or password you provided was not valid.')
            unless $user;
    }

    unless ($user) {
        $c->redirect_with_error(
            error => \@errors,
            uri   => $c->domain()->application_uri(
                path => '/user/login_form', with_host => 1
            ),
            form_data => $c->request()->params(),
        );
    }

    $self->_login_user( $c, $user );
}

sub _login_user {
    my $self = shift;
    my $c    = shift;
    my $user = shift;

    my %expires
        = $c->request()->param('remember') ? ( expires => '+1y' ) : ();
    $c->set_authen_cookie(
        value => { user_id => $user->user_id() },
        %expires,
    );

    $c->session_object()
        ->add_message( 'Welcome to the site, ' . $user->best_name() );

    my $redirect_to = $c->request()->params()->{return_to}
        || $c->domain()->application_uri( path => q{} );

    $c->redirect_and_detach($redirect_to);
}

sub authentication_DELETE {
    my $self = shift;
    my $c    = shift;

    $c->unset_authen_cookie();

    $c->session_object()->add_message('You have been logged out.');

    my $redirect = $c->request()->params()->{return_to}
        || $c->domain()->application_uri( path => q{} );
    $c->redirect_and_detach($redirect);
}

sub new_user_form : Local {
    my $self = shift;
    my $c    = shift;

    $c->stash()->{template} = '/user/new_user_form';
}

sub users_collection : Path('/user') : ActionClass('+Silki::Action::REST') {
}

sub users_collection_POST {
    my $self = shift;
    my $c    = shift;

    my %insert = $c->request()->user_params();

    my @errors = $self->_check_passwords_match(\%insert);

    my $user
        = eval { Silki::Schema::User->insert(%insert) };

    my $e = $@;
    die $e if $e && ! ref $e;

    if ( $e || @errors ) {
        push @errors, @{ $e->errors() } if $e && ref $e;

        $c->redirect_with_error(
            error => \@errors,
            uri   => $c->domain()->application_uri(
                path      => '/user/new_user_form',
                with_host => 1
            ),
            form_data => \%insert,
        );
    }

    $self->_login_user( $c, $user );
}

no Moose;

__PACKAGE__->meta()->make_immutable();

1;

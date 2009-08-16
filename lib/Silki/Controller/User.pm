package Silki::Controller::User;

use strict;
use warnings;

use Silki::Schema::TimeZone;
use Silki::Schema::User;
use Silki::Util qw( string_is_empty );

use Moose;

BEGIN { extends 'Silki::Controller::Base' }

sub login_form : Path
{
    my $self = shift;
    my $c    = shift;

    $c->stash()->{template} = '/user/login_form';
}

sub authentication : Local : ActionClass('+Silki::Action::REST') { }

sub authentication_GET_html
{
    my $self = shift;
    my $c    = shift;

    my $method = $c->request()->param('x-tunneled-method');

    if ( $method && $method eq 'DELETE' )
    {
        $self->authentication_DELETE($c);
        return;
    }
    else
    {
        $c->redirect_and_detach( $c->domain()->application_uri( path => '/user/login_form' ) );
    }
}

sub authentication_POST
{
    my $self = shift;
    my $c    = shift;

    my $username = $c->request()->params->{username};
    my $pw       = $c->request()->params->{password};

    my @errors;

    push @errors, { field   => 'password',
                    message => $c->loc('You must provide a password.') }
        if string_is_empty($pw);

    my $user;
    unless (@errors)
    {
        $user = Silki::Schema::User->new( username => $username,
                                          password => $pw,
                                        );

        push @errors, $c->loc('The username or password you provided was not valid.')
            unless $user;
    }

    unless ($user)
    {
        $c->redirect_with_error
            ( error     => \@errors,
              uri       =>
                  $c->domain()->application_uri( path => '/user/login_form', with_host => 1 ),
              form_data => $c->request()->params(),
            );
    }

    $self->_login_user( $c, $user );
}

sub _login_user
{
    my $self = shift;
    my $c    = shift;
    my $user = shift;

    my %expires = $c->request()->param('remember') ? ( expires => '+1y' ) : ();
    $c->set_authen_cookie( value => { user_id => $user->user_id() },
                           %expires,
                         );

    $c->session_object()->add_message( 'Welcome to the site, ' . $user->best_name() );

    my $redirect_to =
           $c->request()->params()->{return_to}
        || $c->domain()->application_uri( path => q{} );

    $c->redirect_and_detach($redirect_to);
}

sub authentication_DELETE
{
    my $self = shift;
    my $c    = shift;

    $c->unset_authen_cookie();

    $c->session_object()->add_message( 'You have been logged out.' );

    my $redirect = $c->request()->params()->{return_to} || $c->domain()->application_uri( path => q{} );
    $c->redirect_and_detach($redirect);
}

sub _set_user : Chained('/') : PathPart('user') : CaptureArgs(1)
{
    my $self    = shift;
    my $c       = shift;
    my $user_id = shift;

    my $user = Silki::Schema::User->new( user_id => $user_id );

    $c->redirect_and_detach( $c->domain()->uri( with_host => 1 ) )
        unless $user;

    my %profile =
          $c->user()->user_id() == $user->user_id()
        ? ( label   => $c->loc('Your profile'),
            tooltip => $c->loc('View details about your profile'),
          )
        : ( label   => $user->best_name(),
            tooltip => $c->loc( 'Information about %1', $user->best_name() ),
          );

    $c->add_tab( Silki::Web::Tab->new( uri => $user->uri(),
                                       id  => 'profile',
                                       %profile,
                                     )
               );

    if ( $c->user()->can_edit_user($user) )
    {
        my %prefs =
              $c->user()->user_id() == $user->user_id()
            ? ( label   => $c->loc('Your preferences'),
                tooltip => $c->loc('Set your preferences'),
              )
            : ( label   => $c->loc( 'Preferences for %1', $user->best_name() ),
                tooltip => $c->loc( 'View and change preferences for %1', $user->best_name() ),
              );

        $c->add_tab( Silki::Web::Tab->new( uri => $user->uri( view => 'preferences_form' ),
                                           id  => 'preferences',
                                           %prefs,
                                         )
                   );
    }

    $c->stash()->{user} = $user;
}

sub user : Chained('_set_user') : PathPart('') : Args(0) : ActionClass('+Silki::Action::REST') { }

sub user_GET_html
{
    my $self = shift;
    my $c    = shift;

    $c->tab_by_id('profile')->set_is_selected(1);

    $c->stash()->{template} = '/user/profile';
}

sub user_PUT
{
    my $self = shift;
    my $c    = shift;

    my $user = $c->stash()->{user};

    $c->redirect_and_detach( $c->domain()->uri( with_host => 1 ) )
        unless $c->user()->can_edit_user($user);

    my %update = $c->request()->user_params();

    if ( defined $update{password} )
    {
        unless ( defined $update{password2} && $update{password} eq $update{password2} )
        {
            my @e = { field   => 'password',
                      message => $c->loc('The two passwords you provided did not match'),
                    };

            $self->_user_update_error( $c, \@e, \%update );
        }
    }

    eval { $user->update(%update) };

    if ( my $e = $@ )
    {
        $self->_user_update_error( $c, $e, \%update );
    }

    my $message =
          $user->user_id() == $c->user()->user_id()
        ? $c->loc('Your preferences have been updated.')
        : $c->loc( 'Preferences for ' . $user->best_name() . ' have been updated.' );

    $c->session_object()->add_message($message);

    $c->redirect_and_detach( $user->uri() );
}

sub _user_update_error
{
    my $self      = shift;
    my $c         = shift;
    my $errors    = shift;
    my $form_data = shift;

    delete @{ $form_data }{ qw( password password2 ) };

    $c->redirect_with_error
        ( error     => $errors,
          uri       => $c->stash()->{user}->uri( view => 'preferences_form' ),
          form_data => $form_data,
        );
}

sub preferences_form : Chained('_set_user') : PathPart('preferences_form') : Args(0)
{
    my $self = shift;
    my $c    = shift;

    $c->tab_by_id('preferences')->set_is_selected(1);

    $c->stash()->{template} = '/user/preferences_form';
}

no Moose;

__PACKAGE__->meta()->make_immutable();

1;

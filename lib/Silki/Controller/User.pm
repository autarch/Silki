package Silki::Controller::User;

use strict;
use warnings;

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
                    message => 'You must provide a password.' }
        if string_is_empty($pw);

    my $user;
    unless (@errors)
    {
        $user = Silki::Schema::User->new( username => $username,
                                          password => $pw,
                                        );

        push @errors, 'The username or password you provided was not valid.'
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

no Moose;

__PACKAGE__->meta()->make_immutable();

1;

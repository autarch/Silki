package Silki::Controller::Site;

use strict;
use warnings;

use Silki::Schema::Wiki;
use Silki::Util qw( string_is_empty );

use Moose;

BEGIN { extends 'Silki::Controller::Base' }

sub site : Path('/') : Args(0)
{
    my $self = shift;
    my $c    = shift;

    $c->tab_by_id('Home')->set_is_selected(1);

    # XXX - if user is logged in, show all wikis they can see
    $c->stash()->{wiki_count} = Silki::Schema::Wiki->PublicWikiCount();
    $c->stash()->{wikis} = Silki::Schema::Wiki->PublicWikis();

    $c->stash()->{template} = '/site/wikis';
}

sub login_form : Local
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

no Moose;

__PACKAGE__->meta()->make_immutable();

1;

__END__

package Silk::Model::User;

use strict;
use warnings;

use Digest::SHA qw( sha512_base64 );
use Silk::Model::Domain;
use Silk::Model::Schema;

use Fey::Class::Table;
use MooseX::ClassAttribute;

has_table( Silk::Model::Schema->Schema()->table('User') );


class_has 'SystemUser' =>
    ( is      => 'ro',
      isa     => __PACKAGE__,
      lazy    => 1,
      default => sub { __PACKAGE__->_FindOrCreateSystemUser() },
    );

class_has 'GuestUser' =>
    ( is      => 'ro',
      isa     => __PACKAGE__,
      lazy    => 1,
      default => sub { __PACKAGE__->_FindOrCreateGuestUser() },
    );

around 'insert' => sub
{
    my $orig  = shift;
    my $class = shift;
    my %p     = @_;

    if ( delete $p{disable_login} )
    {
        $p{password} = '*disabled*';
    }
    elsif ( $p{password} )
    {
        # XXX - require a certain length or complexity? make it
        # configurable?
        $p{password} = sha512_base64( $p{password} );
    }

    $p{username} ||= $p{email_address};

    return $class->$orig(%p);
};

sub EnsureRequiredUsersExist
{
    my $class = shift;

    $class->_FindOrCreateSystemUser();

    $class->_FindOrCreateGuestUser();
}

{
    my $SystemUsername = 'system-user';

    sub _FindOrCreateSystemUser
    {
        my $class = shift;

        return $class->_FindOrCreateSpecialUser($SystemUsername);
    }
}

{
    my $GuestUsername = 'guest-user';

    sub _FindOrCreateGuestUser
    {
        my $class = shift;

        return $class->_FindOrCreateSpecialUser($GuestUsername);
    }
}

sub _FindOrCreateSpecialUser
{
    my $class    = shift;
    my $username = shift;

    my $user = eval { $class->new( username => $username ) };

    return $user if $user;

    return $class->_CreateSpecialUser($username);
}

sub _CreateSpecialUser
{
    my $class    = shift;
    my $username = shift;

    my $domain = Silk::Model::Domain->DefaultDomain();

    my $email = $username . q{@} . $domain->hostname();

    my $display_name = join ' ', map { ucfirst } split /-/, $username;

    return $class->insert( display_name   => $display_name,
                           username       => $username,
                           email_address  => $email,
                           disable_login  => 1,
                           is_system_user => 1,
                         );
}


no Fey::Class::Table;
no Moose;
no MooseX::ClassAttribute;

__PACKAGE__->meta()->make_immutable();


1;

__END__



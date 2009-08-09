package Silki::AppRole::User;

use strict;
use warnings;

use Silki::Schema::User;

use Moose::Role;

has 'user' =>
    ( is      => 'ro',
      isa     => 'Silki::Schema::User',
      lazy    => 1,
      builder => '_build_user',
    );


sub _build_user
{
    my $self = shift;

    my $cookie = $self->authen_cookie_value();

    my $user;
    $user = Silki::Schema::User->new( user_id => $cookie->{user_id} )
        if $cookie->{user_id};

    return $user = Silki::Schema::User->GuestUser();
}

no Moose::Role;

1;

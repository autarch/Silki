package Silki::Controller::User;

use strict;
use warnings;

use Silki::Schema::TimeZone;
use Silki::Schema::User;

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

no Moose;

__PACKAGE__->meta()->make_immutable();

1;

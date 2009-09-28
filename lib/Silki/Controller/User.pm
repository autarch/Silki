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

no Moose;

__PACKAGE__->meta()->make_immutable();

1;

package Silki::Controller::Site;

use strict;
use warnings;
use namespace::autoclean;

use Silki::Schema::User;
use Silki::Schema::Wiki;

use Moose;

BEGIN { extends 'Silki::Controller::Base' }

with qw(
    Silki::Role::Controller::Pager
);

sub site : Path('/') : Args(0) {
    my $self = shift;
    my $c    = shift;

    if ( $c->user()->is_authenticated() ) {
        $c->stash()->{user_wiki_count} = $c->user()->member_wiki_count();
        $c->stash()->{user_wikis}      = $c->user()->member_wikis();
    }

    $c->stash()->{public_wiki_count} = Silki::Schema::Wiki->PublicWikiCount();
    $c->stash()->{public_wikis}      = Silki::Schema::Wiki->PublicWikis();

    $c->stash()->{template} = '/site/dashboard';
}

sub system_log : Path('/logs') : Args(0) {
    my $self = shift;
    my $c    = shift;

    $self->_require_site_admin($c);

    my ( $limit, $offset )
        = $self->_make_pager( $c, Silki::Schema::SystemLog->Count() );

    $c->stash()->{logs} = Silki::Schema::SystemLog->All(
        limit  => $limit,
        offset => $offset,
    );

    $c->stash()->{template} = '/log/logs';
}

sub help : Path('/help') : Args(0) {
    my $self = shift;
    my $c    = shift;

    $c->stash()->{template} = '/site/help.en';
}

__PACKAGE__->meta()->make_immutable();

1;

__END__

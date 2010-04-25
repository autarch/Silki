package Silki::Controller::Site;

use strict;
use warnings;

use Silki::Schema::User;
use Silki::Schema::Wiki;

use Moose;

BEGIN { extends 'Silki::Controller::Base' }

with qw( Silki::Role::Controller::Pager );

sub site : Path('/') : Args(0) {
    my $self = shift;
    my $c    = shift;

    if ( $c->user()->is_authenticated() ) {
        $c->stash()->{user_wiki_count} = $c->user()->member_wiki_count();
        $c->stash()->{user_wikis}      = $c->user()->member_wikis();
    }

    $c->stash()->{public_wiki_count} = Silki::Schema::Wiki->PublicWikiCount();
    $c->stash()->{public_wikis}      = Silki::Schema::Wiki->PublicWikis();

    $c->stash()->{template} = '/site/wikis';
}

sub wikis : Path('/wikis') : Args(0) {
    my $self = shift;
    my $c    = shift;

    unless ( $c->user()->is_admin() ) {
        $c->redirect_and_detach( $self->_site_uri($c) );
    }

    my ( $limit, $offset ) = $self->_make_pager( $c, Silki::Schema::Wiki->Count() );

    $c->stash()->{wikis} = Silki::Schema::Wiki->All(
        limit  => $limit,
        offset => $offset,
    );

    $c->stash()->{template} = '/site/admin/wikis';
}

sub _site_uri {
    my $self = shift;
    my $c = shift;

    # XXX - this needs to figure out the correct hostname and port - but
    # Catalyst::Request doesn't include the requested hostname.
    return '/';
}

no Moose;

__PACKAGE__->meta()->make_immutable();

1;

__END__

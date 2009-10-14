package Silki::Controller::Site;

use strict;
use warnings;

use Silki::Schema::User;
use Silki::Schema::Wiki;

use Moose;

BEGIN { extends 'Silki::Controller::Base' }

sub site : Path('/') : Args(0) {
    my $self = shift;
    my $c    = shift;

    $c->tab_by_id('Home')->set_is_selected(1);

    if ( $c->user()->is_authenticated() ) {
        $c->stash()->{user_wiki_count} = $c->user()->private_wiki_count();
        $c->stash()->{user_wikis}      = $c->user()->private_wikis();
    }

    $c->stash()->{public_wiki_count} = Silki::Schema::Wiki->PublicWikiCount();
    $c->stash()->{public_wikis}      = Silki::Schema::Wiki->PublicWikis();

    $c->stash()->{template} = '/site/wikis';
}

no Moose;

__PACKAGE__->meta()->make_immutable();

1;

__END__

package Silki::Controller::Site;

use strict;
use warnings;

use Silki::Schema::Wiki;

use Moose;

BEGIN { extends 'Silki::Controller::Base' }

__PACKAGE__->config( namespace => q{} );

sub site : Path('')
{
    my $self = shift;
    my $c    = shift;

    # XXX - if user is logged in, show all wikis they can see
    $c->stash()->{wiki_count} = Silki::Schema::Wiki->PublicWikiCount();
    $c->stash()->{wikis} = Silki::Schema::Wiki->PublicWikis();

    $c->stash()->{template} = '/site/wikis';
}

sub end : ActionClass('RenderView') { }

no Moose;

__PACKAGE__->meta()->make_immutable();

1;

__END__

package Silki::Controller::Wiki;

use strict;
use warnings;

use Moose;

BEGIN { extends 'Silki::Controller::Base' }

sub _set_wiki : Chained('/') : PathPart('wiki') : CaptureArgs(1)
{
    my $self      = shift;
    my $c         = shift;
    my $wiki_name = shift;

    my $wiki = Silki::Schema::Wiki->new( short_name => $wiki_name );

    $c->redirect_and_detach( $c->domain()->uri( with_host => 1 ) )
        unless $wiki;

    $c->stash()->{wiki} = $wiki;
}

sub no_page : Chained('_set_wiki') : PathPart('') : Args(0) : ActionClass('+Silki::Action::REST') { }

sub no_page_GET_html
{
    my $self = shift;
    my $c    = shift;

    my $uri = $c->stash()->{wiki}->uri( view => 'dashboard' );

    $c->redirect_and_detach($uri);
}

sub dashboard : Chained('_set_wiki') : PathPart('dashboard') : Args(0)
{
    my $self = shift;
    my $c    = shift;

    $c->stash->{template} = '/wiki/dashboard';
}

sub page : Chained('_set_wiki') : PathPart('page') : Args(1) : ActionClass('+Silki::Action::REST') { }

sub page_GET_html
{
    my $self      = shift;
    my $c         = shift;
    my $page_path = shift;

    my $wiki = $c->stash()->{wiki};

    my $page =
        Silki::Schema::Page->new( uri_path => $page_path,
                                  wiki_id  => $wiki->wiki_id(),
                                );

    $c->redirect_and_detach( $wiki->uri( with_host => 1 ) )
        unless $page;

    $c->stash()->{page} = $page;

    $c->stash->{template} = '/page/view';
}

no Moose;

__PACKAGE__->meta()->make_immutable();

1;

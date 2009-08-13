package Silki::Controller::Wiki;

use strict;
use warnings;

use Silki::Web::Tab;

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

    $self->_require_permission_for_wiki( $c, $wiki );

    $c->add_tab($_)
        for map { Silki::Web::Tab->new( %{ $_ } ) }
            ( { uri     => $wiki->uri(),
                label   => 'Dashboard',
                tooltip => 'Wiki overview',
              },
              { uri     => $wiki->uri( view => 'recent' ),
                label   => 'Recent Changes',
                tooltip => 'Recent activity in this wiki',
              },
            );

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

    $c->tab_by_label('Dashboard')->set_is_selected(1);

    $c->stash()->{template} = '/wiki/dashboard';
}

sub recent : Chained('_set_wiki') : PathPart('recent') : Args(0)
{
    my $self = shift;
    my $c    = shift;

    $c->tab_by_label('Recent Changes')->set_is_selected(1);

    my $limit = 20;
    my $offset = $limit * ( $c->request()->params()->{page} ? $c->request()->params()->{page} - 1 : 0 );

    my $wiki = $c->stash()->{wiki};

    $c->stash()->{pages} =
        $wiki->recently_changed_pages( limit  => $limit,
                                       offset => $offset,
                                     );

    $c->stash()->{title} = 'Recent Changes in ' . $wiki->title();
    $c->stash()->{template} = '/wiki/recent';
}

sub new_page_form : Chained('_set_wiki') : PathPart('new_page_form') : Args(0)
{
    my $self = shift;
    my $c    = shift;

    $c->stash()->{title} = $c->request()->params()->{title};
    $c->stash()->{template} = '/wiki/new_page_form';
}

sub page_collection : Chained('_set_wiki') : PathPart('page') : Args(0) : ActionClass('+Silki::Action::REST') { }

sub page_collection_POST
{
    my $self      = shift;
    my $c         = shift;

    my $page =
        Silki::Schema::Page->insert_with_content
            ( title   => $c->request()->params()->{title},
              content => $c->request()->params()->{content},
              wiki_id => $c->stash()->{wiki}->wiki_id(),
              user_id => $c->user()->user_id(),
            );

    $c->redirect_and_detach( $page->uri() );
}

sub _set_page : Chained('_set_wiki') : PathPart('page') : CaptureArgs(1)
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

    $c->add_tab( Silki::Web::Tab->new
                     ( uri     => $page->uri(),
                       label   => $page->title(),
                       tooltip => 'View this page',
                       is_selected => 1,
                     )
               );

    $c->stash()->{page} = $page;
}

sub page : Chained('_set_page') : PathPart('') : Args(0) : ActionClass('+Silki::Action::REST') { }

sub page_GET_html
{
    my $self      = shift;
    my $c         = shift;

    $c->stash()->{html} = $self->_page_content_as_html( $c, $c->stash()->{page} );
    $c->stash()->{template} = '/page/view';
}

sub page_edit_form : Chained('_set_page') : PathPart('edit_form') : Args(0)
{
    my $self      = shift;
    my $c         = shift;

    $c->stash()->{template} = '/page/edit_form';
}

sub page_PUT
{
    my $self = shift;
    my $c    = shift;

    my $page = Silki::Schema::Page->new( page_id => $c->request()->params()->{page_id} );

    $page->add_revision( content => $c->request()->params()->{content},
                         user_id => $c->user()->user_id(),
                       );

    $c->redirect_and_detach( $page->uri() );
}

sub _page_content_as_html : Private
{
    my $self = shift;
    my $c    = shift;
    my $page = shift;

    my $formatter =
        Silki::Formatter->new( user => $c->user(),
                               wiki => $page->wiki(),
                             );

    return $formatter->wikitext_to_html( $page->content() );
}

no Moose;

__PACKAGE__->meta()->make_immutable();

1;

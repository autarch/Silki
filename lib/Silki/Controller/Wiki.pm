package Silki::Controller::Wiki;

use strict;
use warnings;

use Data::Page;
use Data::Page::FlickrLike;
use List::AllUtils qw( all );
use Silki::Formatter;
use Silki::Schema::Page;
use Silki::Schema::PageRevision;
use Silki::Schema::Wiki;
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
                label   => $c->loc( 'Dashboard' ),
                tooltip => $c->loc( 'Wiki overview' ),
              },
              { uri     => $wiki->uri( view => 'recent' ),
                label   => $c->loc( 'Recent Changes' ),
                tooltip => $c->loc( 'Recent activity in this wiki' ),
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

    $c->tab_by_label( $c->loc('Recent Changes') )->set_is_selected(1);

    my $limit = 20;
    my $offset = $limit * ( $c->request()->params()->{page} ? $c->request()->params()->{page} - 1 : 0 );

    my $wiki = $c->stash()->{wiki};

    $c->stash()->{pages} =
        $wiki->recently_changed_pages( limit  => $limit,
                                       offset => $offset,
                                     );

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
                     ( uri         => $page->uri(),
                       label       => $page->title(),
                       tooltip     => $c->loc( 'View this page' ),
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

    my $page = $c->stash()->{page};
    my $revision = $page->most_recent_revision();

    $c->stash()->{page} = $page;
    $c->stash()->{revision} = $revision;
    $c->stash()->{is_current_revision} = 1;
    $c->stash()->{html} = $self->_rev_content_as_html( $c, $revision, $page );

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

sub _rev_content_as_html : Private
{
    my $self = shift;
    my $c    = shift;
    my $rev  = shift;
    my $page = shift;

    my $formatter =
        Silki::Formatter->new( user => $c->user(),
                               wiki => $page->wiki(),
                             );

    return $formatter->wikitext_to_html( $rev->content() );
}

sub page_revision : Chained('_set_page') : PathPart('revision') : Args(1)
{
    my $self            = shift;
    my $c               = shift;
    my $revision_number = shift;

    my $page = $c->stash()->{page};

    my $revision;
    if ( $revision_number =~ /^\d+$/ )
    {
        $revision = Silki::Schema::PageRevision->new( page_id         => $page->page_id(),
                                                      revision_number => $revision_number,
                                                    );
    }

    unless ($revision)
    {
        $c->redirect_and_detch( $page->uri( with_host => 1 ) );
    }

    $c->stash()->{page} = $page;
    $c->stash()->{revision} = $revision;
    $c->stash()->{is_current_revision} = 0;
    $c->stash()->{html} = $self->_rev_content_as_html( $c, $revision, $page );

    $c->stash()->{template} = '/page/view';
}

sub page_history : Chained('_set_page') : PathPart('history') : Args(0)
{
    my $self      = shift;
    my $c         = shift;

    my $limit = 20;
    my $page_num = $c->request()->params()->{page} || 1;
    my $offset = $limit * ( $page_num - 1 );

    my $page = $c->stash()->{page};

    my $pager = Data::Page->new();
    $pager->total_entries( $page->most_recent_revision()->revision_number());
    $pager->entries_per_page($limit);
    $pager->current_page($page_num);

    $c->stash()->{pager} = $pager;

    $c->stash()->{revisions} = $page->revisions( limit => $limit, offset => $offset );

    $c->stash()->{template} = '/page/history';
}

sub page_diff : Chained('_set_page') : PathPart('diff') : Args(0)
{
    my $self = shift;
    my $c    = shift;

    my $page = $c->stash()->{page};

    my @nums = ( $c->request()->params()->{revision1}, $c->request()->params()->{revision2} );

    unless ( ( @nums == 2 ) && all { defined && /^\d+$/ } @nums )
    {
        $c->redirect_and_detach( $page->uri( with_host => 1 ) );
    }

    my @revisions =
        map { Silki::Schema::PageRevision->new( page_id         => $page->page_id(),
                                                revision_number => $_ ) }
        sort
        @nums;

    $c->stash()->{rev1} = $revisions[0];
    $c->stash()->{rev2} = $revisions[1];
    $c->stash()->{diff} = Silki::Schema::PageRevision->Diff( rev1 => $revisions[0],
                                                             rev2 => $revisions[1],
                                                           );

    $c->stash()->{template} = '/page/diff';
}

no Moose;

__PACKAGE__->meta()->make_immutable();

1;

package Silki::Controller::Page;

use strict;
use warnings;

use List::AllUtils qw( all );
use Silki::I18N qw( loc );
use Silki::Formatter::HTMLToWiki;
use Silki::Formatter::WikiToHTML;
use Silki::Schema::Page;
use Silki::Schema::PageRevision;

use Moose;

BEGIN { extends 'Silki::Controller::Base' }

with qw(
    Silki::Role::Controller::Pager
    Silki::Role::Controller::RevisionsAtomFeed
    Silki::Role::Controller::UploadHandler
    Silki::Role::Controller::WikitextHandler
);

sub _set_page : Chained('/wiki/_set_wiki') : PathPart('page') : CaptureArgs(1) {
    my $self      = shift;
    my $c         = shift;

    # Catalyst URI-unescapes the path pieces when passing them to controller
    # methods, which is really annoying. Fortunately, the request still has
    # the original form.
    my $page_path = ( split /\//, $c->request()->path_info() )[3];

    my $wiki = $c->stash()->{wiki};

    my $page = Silki::Schema::Page->new(
        uri_path => $page_path,
        wiki_id  => $wiki->wiki_id(),
    );

    $c->redirect_and_detach( $wiki->uri( with_host => 1 ) )
        unless $page;

    if ( $page->title() eq $wiki->front_page_title() ) {
        $c->tab_by_id('front-page')->set_is_selected(1);
    }
    else {
        $c->add_tab(
            {
                uri         => $page->uri(),
                label       => $page->title(),
                tooltip     => loc('View this page'),
                is_selected => 1,
            }
        );
    }

    $c->stash()->{page} = $page;
}

sub page : Chained('_set_page') : PathPart('') : Args(0) : ActionClass('+Silki::Action::REST') {
}

sub page_GET_html {
    my $self = shift;
    my $c    = shift;

    my $page     = $c->stash()->{page};
    my $revision = $page->most_recent_revision();

    $page->record_view( $c->user() );

    $c->stash()->{page}                = $page;
    $c->stash()->{revision}            = $revision;
    $c->stash()->{is_current_revision} = 1;
    $c->stash()->{html}                = $revision->content_as_html(
        user => $c->user(),
    );

    $c->stash()->{template} = '/page/view';
}

sub page_edit_form : Chained('_set_page') : PathPart('edit_form') : Args(0) {
    my $self = shift;
    my $c    = shift;

    $self->_require_permission_for_wiki( $c, $c->stash()->{wiki}, 'Edit' );

    my $page = $c->stash()->{page};

    $c->stash()->{html} = $page->most_recent_revision()->content_as_html(
        user       => $c->user(),
        for_editor => 1,
    );

    $c->stash()->{template} = '/page/edit_form';
}

sub page_PUT {
    my $self = shift;
    my $c    = shift;

    $self->_require_permission_for_wiki( $c, $c->stash()->{wiki} );

    my $page = Silki::Schema::Page->new(
        page_id => $c->request()->params()->{page_id} );

    my $wikitext = $self->_wikitext_from_form( $c, $page->wiki() );

    $page->add_revision(
        content => $wikitext,
        user_id => $c->user()->user_id(),
    );

    $c->redirect_and_detach( $page->uri() );
}

sub revision : Chained('_set_page') : PathPart('revision') : Args(1) {
    my $self            = shift;
    my $c               = shift;
    my $revision_number = shift;

    my $page = $c->stash()->{page};

    my $revision;
    if ( $revision_number =~ /^\d+$/ ) {
        $revision = Silki::Schema::PageRevision->new(
            page_id         => $page->page_id(),
            revision_number => $revision_number,
        );
    }

    unless ($revision) {
        $c->redirect_and_detach( $page->uri( with_host => 1 ) );
    }

    if ( $revision->revision_number() == $page->most_recent_revision()->revision_number() ) {
        $c->redirect_and_detach( $page->uri( with_host => 1 ) );
    }

    $c->stash()->{page}                = $page;
    $c->stash()->{revision}            = $revision;
    $c->stash()->{is_current_revision} = 0;
    $c->stash()->{html}                = $revision->content_as_html(
        user => $c->user(),
    );

    $c->stash()->{template} = '/page/view';
}

sub history : Chained('_set_page') : PathPart('history') : Args(0) {
    my $self = shift;
    my $c    = shift;

    my $page = $c->stash()->{page};

    my ( $limit, $offset ) = $self->_make_pager(
        $c,
        $page->most_recent_revision()->revision_number(),
    );

    $c->stash()->{revisions} = $page->revisions(
        limit  => $limit,
        offset => $offset,
    );

    $c->stash()->{template} = '/page/history';
}

sub history_atom : Chained('_set_page') : PathPart('history.atom') : Args(0) {
    my $self = shift;
    my $c    = shift;

    my $page = $c->stash()->{page};

    my $revisions = $page->revisions( limit => 50 );

    $self->_output_atom_feed_for_revisions(
        $c,
        $revisions,
        loc( 'History for %1', $page->title() ),
        $page->uri( view => 'history',      with_host => 1 ),
        $page->uri( view => 'history.atom', with_host => 1 ),
        $page,
    );
}

sub diff : Chained('_set_page') : PathPart('diff') : Args(0) {
    my $self = shift;
    my $c    = shift;

    my $page = $c->stash()->{page};

    my @nums = ( $c->request()->params()->{revision1},
        $c->request()->params()->{revision2} );

    unless ( ( @nums == 2 ) && all { defined && /^\d+$/ } @nums ) {
        $c->redirect_and_detach( $page->uri( with_host => 1 ) );
    }

    my @revisions
        = map {
        Silki::Schema::PageRevision->new(
            page_id         => $page->page_id(),
            revision_number => $_
            )
        }
        sort @nums;

    $c->stash()->{rev1} = $revisions[0];
    $c->stash()->{rev2} = $revisions[1];
    $c->stash()->{diff} = Silki::Schema::PageRevision->Diff(
        rev1 => $revisions[0],
        rev2 => $revisions[1],
    );

    $c->stash()->{formatter} = Silki::Formatter::WikiToHTML->new(
        user => $c->user(),
        wiki => $c->stash()->{wiki},
    );

    $c->stash()->{template} = '/page/diff';
}

sub attachments : Chained('_set_page') : PathPart('attachments') : Args(0) {
    my $self = shift;
    my $c    = shift;

    $c->stash()->{file_count} = $c->stash()->{page}->file_count();
    $c->stash()->{files} = $c->stash()->{page}->files();

    $c->stash()->{template} = '/page/attachments';
}

sub file_collection : Chained('_set_page') : PathPart('files') : Args(0) : ActionClass('+Silki::Action::REST') {
}

sub file_collection_POST {
    my $self = shift;
    my $c    = shift;

    $self->_require_permission_for_wiki( $c, $c->stash()->{wiki}, 'Upload' );

    my $upload = $c->request()->upload('file');

    $self->_handle_upload(
        $c,
        $upload,
        $c->stash()->{page}->uri( view => 'attachments' ),
    );

    $c->session_object()->add_message( loc('The file has been uploaded, and this page now links to the file.' ) );
    $c->redirect_and_detach( $c->stash()->{page}->uri( view => 'attachments' ) );
}

no Moose;

__PACKAGE__->meta()->make_immutable();

1;

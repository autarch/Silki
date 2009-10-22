package Silki::Controller::Page;

use strict;
use warnings;

use Data::Page;
use Silki::I18N qw( loc );
use Silki::Formatter::HTMLToWiki;
use Silki::Formatter::WikiToHTML;
use Silki::Schema::Page;
use Silki::Schema::PageRevision;

use Moose;

BEGIN { extends 'Silki::Controller::Base' }

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

    $c->add_tab(
        {
            uri         => $page->uri(),
            label       => $page->title(),
            tooltip     => loc('View this page'),
            is_selected => 1,
        }
    );

    $c->stash()->{page} = $page;
}

sub page : Chained('_set_page') : PathPart('') : Args(0) : ActionClass('+Silki::Action::REST') {
}

sub page_GET_html {
    my $self = shift;
    my $c    = shift;

    my $page     = $c->stash()->{page};
    my $revision = $page->most_recent_revision();

    $c->stash()->{page}                = $page;
    $c->stash()->{revision}            = $revision;
    $c->stash()->{is_current_revision} = 1;
    $c->stash()->{html} = $self->_rev_content_as_html( $c, $revision, $page );

    $c->stash()->{template} = '/page/view';
}

sub page_edit_form : Chained('_set_page') : PathPart('edit_form') : Args(0) {
    my $self = shift;
    my $c    = shift;

    my $page = $c->stash()->{page};

    $c->stash()->{html} = $self->_rev_content_as_html(
        $c,
        $page->most_recent_revision(),
        $page,
        1,
    );

    $c->stash()->{template} = '/page/edit_form';
}

sub page_PUT {
    my $self = shift;
    my $c    = shift;

    my $page = Silki::Schema::Page->new(
        page_id => $c->request()->params()->{page_id} );

    my $formatter = Silki::Formatter::HTMLToWiki->new(
        user => $c->user(),
        wiki => $page->wiki(),
    );

    my $wikitext
        = $formatter->html_to_wikitext( $c->request()->params()->{content} );

    $page->add_revision(
        content => $wikitext,
        user_id => $c->user()->user_id(),
    );

    $c->redirect_and_detach( $page->uri() );
}

sub _rev_content_as_html : Private {
    my $self       = shift;
    my $c          = shift;
    my $rev        = shift;
    my $page       = shift;
    my $for_editor = shift;

    my $formatter = Silki::Formatter::WikiToHTML->new(
        user       => $c->user(),
        wiki       => $page->wiki(),
        for_editor => $for_editor,
    );

    return $formatter->wikitext_to_html( $rev->content() );
}

sub page_revision : Chained('_set_page') : PathPart('revision') : Args(1) {
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
        $c->redirect_and_detch( $page->uri( with_host => 1 ) );
    }

    $c->stash()->{page}                = $page;
    $c->stash()->{revision}            = $revision;
    $c->stash()->{is_current_revision} = 0;
    $c->stash()->{html} = $self->_rev_content_as_html( $c, $revision, $page );

    $c->stash()->{template} = '/page/view';
}

sub page_history : Chained('_set_page') : PathPart('history') : Args(0) {
    my $self = shift;
    my $c    = shift;

    my $limit    = 20;
    my $page_num = $c->request()->params()->{page} || 1;
    my $offset   = $limit * ( $page_num - 1 );

    my $page = $c->stash()->{page};

    my $pager = Data::Page->new();
    $pager->total_entries( $page->most_recent_revision()->revision_number() );
    $pager->entries_per_page($limit);
    $pager->current_page($page_num);

    $c->stash()->{pager} = $pager;

    $c->stash()->{revisions}
        = $page->revisions( limit => $limit, offset => $offset );

    $c->stash()->{template} = '/page/history';
}

sub page_diff : Chained('_set_page') : PathPart('diff') : Args(0) {
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
        wiki => $page->wiki(),
    );

    $c->stash()->{template} = '/page/diff';
}

sub page_attachments : Chained('_set_page') : PathPart('attachments') : Args(0) {
    my $self = shift;
    my $c    = shift;

    $c->stash()->{file_count} = $c->stash()->{page}->file_count();
    $c->stash()->{files} = $c->stash()->{page}->files();

    $c->stash()->{template} = '/page/attachments';
}

sub page_file_collection : Chained('_set_page') : PathPart('file') : Args(0) : ActionClass('+Silki::Action::REST') {
}

sub page_file_collection_POST {
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

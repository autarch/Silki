package Silki::Controller::File;

use strict;
use warnings;

use Silki::Schema::File;

use Moose;

BEGIN { extends 'Silki::Controller::Base' }

sub _set_file : Chained('/wiki/_set_wiki') : PathPart('file') : CaptureArgs(1) {
    my $self    = shift;
    my $c       = shift;
    my $file_id = shift;

    my $file = Silki::Schema::File->new( file_id => $file_id );

    my $wiki = $c->stash()->{wiki};
    $c->redirect_and_detach( $wiki->uri( with_host => 1 ) )
        unless $file && $file->wiki_id() == $wiki->wiki_id();

    $c->stash()->{file} = $file;
}

sub file : Chained('_set_file') : PathPart('') : Args(0) : ActionClass('+Silki::Action::REST') {
}

sub file_GET_html {
    my $self = shift;
    my $c    = shift;

    my $file = $c->stash()->{file};

    if ( $file->is_displayable_in_browser() ) {
        $c->stash()->{template} = '/file/view-in-frame';
    }
    else {
        $self->_file_download( $c, $file );
    }

    return;
}

sub file_download : Chained('_set_file') : PathPart('download') : Args(0) {
    my $self = shift;
    my $c    = shift;

    $self->_file_download( $c, $c->stash()->{file}, 'inline' );

    return;
}

sub _file_download {
    my $self        = shift;
    my $c           = shift;
    my $file        = shift;
    my $disposition = shift || 'attachment';

    $c->response()->content_type( $file->mime_type() );

    my $name = $file->file_name();
    $name =~ s/\"/\\"/g;

    $c->response()
        ->header( 'Content-Disposition' => qq{$disposition; filename="$name"} );
    $c->response()->content_length( $file->file_size() );
    $c->response()->header( 'X-Sendfile' => $file->file_on_disk() );
}

sub file_thumbnail : Chained('_set_file') : PathPart('thumbnail') : Args(0) {
    my $self = shift;
    my $c    = shift;

    my $file = $c->stash()->{file};

    $c->status_not_found()
        unless $file->is_browser_displayable_image();

    my $thumbnail = $file->thumbnail_file();

    $c->response()->status(200);
    $c->response()->content_type( $file->mime_type() );
    $c->response()->content_length( -s $thumbnail );
    $c->response()->header( 'X-Sendfile' => $thumbnail );

    return;
}

no Moose;

__PACKAGE__->meta()->make_immutable();

1;

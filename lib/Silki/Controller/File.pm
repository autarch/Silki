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
        $self->_download( $c, $file, 'attachment' );
    }

    return;
}

sub content : Chained('_set_file') : PathPart('content') : Args(0) {
    my $self = shift;
    my $c    = shift;

    my $file = $c->stash()->{file};

    # If the file type is something like text/x-python, the browser might
    # prompt the user to save the file. However, if we force text/plain, the
    # browser displays the file nicely.
    my $ct = $file->mime_type() =~ /^text/ ? 'text/plain' : $file->mime_type();

    $self->_download( $c, $file, 'inline', $ct );

    return;
}

sub download : Chained('_set_file') : PathPart('download') : Args(0) {
    my $self = shift;
    my $c    = shift;

    $self->_download( $c, $c->stash()->{file}, 'attachment' );

    return;
}

sub _download {
    my $self         = shift;
    my $c            = shift;
    my $file         = shift;
    my $disposition  = shift;
    my $content_type = shift || $file->mime_type();

    $c->response()->content_type($content_type);

    my $name = $file->file_name();
    $name =~ s/\"/\\"/g;

    $c->response()
        ->header( 'Content-Disposition' => qq{$disposition; filename="$name"} );
    $c->response()->content_length( $file->file_size() );
    $c->response()->header( 'X-Sendfile' => $file->file_on_disk() );
}

sub thumbnail : Chained('_set_file') : PathPart('thumbnail') : Args(0) {
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

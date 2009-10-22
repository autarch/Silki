package Silki::Role::Controller::UploadHandler;

use strict;
use warnings;

use File::MimeInfo qw( mimetype );
use Silki::I18N qw( loc );

use Moose::Role;

sub _handle_upload {
    my $self   = shift;
    my $c      = shift;
    my $upload = shift;
    my $on_error = shift;

    unless ($upload) {
        $c->redirect_with_error(
            error => loc('You did not select a file to upload.'),
            uri   => $on_error,
        );
    }

    if ( $upload->size() > Silki::Config->new()->max_upload_size() ) {
        $c->redirect_with_error(
            error => loc('The file you uploaded was too large.'),
            uri   => $on_error,
        );
    }

    # Copied the logic from Catalyst::Request::Upload without the last step of
    # removing most characters.
    my $basename = $upload->filename;
    $basename =~ s|\\|/|g;
    $basename = ( File::Spec::Unix->splitpath($basename) )[2];

    my $file;
    Silki::Schema->RunInTransaction(
        sub {
            $file = Silki::Schema::File->insert(
                file_name => $basename,
                mime_type => mimetype( $upload->tempname() ),
                file_size => $upload->size(),
                contents  => do { my $fh = $upload->fh(); local $/; <$fh> },
                user_id   => $c->user()->user_id(),
                wiki_id   => $c->stash()->{wiki}->wiki_id(),
            );

            $c->stash()->{page}->add_file($file)
                if $c->stash()->{page};
        }
    );
}

no Moose::Role;

1;

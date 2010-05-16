package Silki::Role::Controller::UploadHandler;

use strict;
use warnings;
use namespace::autoclean;

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

    if ( $upload->size() == 0 ) {
        $c->redirect_with_error(
            error => loc('The file you uploaded was empty.'),
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

{
    use HTTP::Body::MultiPart;
    package HTTP::Body::MultiPart;

    no warnings 'redefine';
sub handler {
    my ( $self, $part ) = @_;

    unless ( exists $part->{name} ) {

        my $disposition = $part->{headers}->{'Content-Disposition'};
        my ($name)      = $disposition =~ / name="?([^\";]+)"?/;
        my ($filename)  = $disposition =~ / filename="?([^\"]*)"?/;
        # Need to match empty filenames above, so this part is flagged as an upload type

        $part->{name} = $name;

        if ( defined $filename ) {
            $part->{filename} = $filename;

            if ( $filename ne "" ) {
                # XXX - this is the monkey patch, adding the filename as a
                # suffix so that we preserve the file's extension
                my $fh = File::Temp->new( UNLINK => 0, DIR => $self->tmpdir, SUFFIX => q{-} . $filename );

                $part->{fh}       = $fh;
                $part->{tempname} = $fh->filename;
            }
        }
    }

    if ( $part->{fh} && ( my $length = length( $part->{data} ) ) ) {
        $part->{fh}->write( substr( $part->{data}, 0, $length, '' ), $length );
    }

    if ( $part->{done} ) {

        if ( exists $part->{filename} ) {
            if ( $part->{filename} ne "" ) {
                $part->{fh}->close if defined $part->{fh};

                delete @{$part}{qw[ data done fh ]};

                $self->upload( $part->{name}, $part );
            }
        }
        else {
            $self->param( $part->{name}, $part->{data} );
        }
    }
}
}

1;

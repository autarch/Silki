package Silki::Schema::File;

use strict;
use warnings;
use namespace::autoclean;

use autodie;
use Digest::SHA qw( sha256_hex );
use File::MimeInfo qw( describe );
use File::stat;
use Image::Magick;
use Image::Thumbnail;
use List::AllUtils qw( any );
use Silki::Config;
use Silki::I18N qw( loc );
use Silki::Schema;
use Silki::Types qw( Str Bool File Maybe );

use Fey::ORM::Table;

with 'Silki::Role::Schema::URIMaker';

with 'Silki::Role::Schema::SystemLogger' => { methods => ['delete'] };

with 'Silki::Role::Schema::DataValidator' => {
    steps => [
        '_filename_is_unique_for_page',
    ],
};

my $Schema = Silki::Schema->Schema();

has_policy 'Silki::Schema::Policy';

has_table( $Schema->table('File') );

has_one( $Schema->table('User') );

has_one page => (
    table   => $Schema->table('Page'),
    handles => ['wiki'],
);

has is_displayable_in_browser => (
    is       => 'ro',
    isa      => Bool,
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_is_displayable_in_browser',
);

has is_browser_displayable_image => (
    is       => 'ro',
    isa      => Bool,
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_is_browser_displayable_image',
);

has file_on_disk => (
    is       => 'ro',
    isa      => File,
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_file_on_disk',
    clearer  => '_clear_file_on_disk',    # for testing
);

has small_image_file => (
    is       => 'ro',
    isa      => Maybe[File],
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_small_image_file',
);

has thumbnail_file => (
    is       => 'ro',
    isa      => Maybe[File],
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_thumbnail_file',
);

has _filename_with_hash => (
    is       => 'ro',
    isa      => Str,
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_filename_with_hash',
);

sub _system_log_values_for_delete {
    my $self = shift;

    my $msg
        = 'Deleted file, '
        . $self->filename()
        . ', attached to '
        . $self->page()->title()
        . ' in '
        . $self->wiki()->title();

    return (
        page_id   => $self->page_id(),
        message   => $msg,
        data_blob => {
            filename => $self->filename(),
            mime_type => $self->mime_type(),
            file_size => $self->file_size(),
        },
    );
}

sub _filename_is_unique_for_page {
    my $self      = shift;
    my $p         = shift;
    my $is_insert = shift;

    return
        if !$is_insert
            && exists $p->{filename}
            && $p->{filename} eq $self->filename();

    return unless exists $p->{filename};

    return
        unless __PACKAGE__->new(
        filename => $p->{filename},
        page_id  => $p->{page_id},
        );

    return {
        message => loc(
            'The filename you provided is already in use for another file on this page.'
        ),
    };
}

sub _base_uri_path {
    my $self = shift;

    return $self->wiki()->_base_uri_path() .  '/file/' . $self->file_id();
}

sub mime_type_description_for_lang {
    my $self = shift;
    my $lang = shift;

    my $desc = describe( $self->mime_type(), $lang );
    $desc ||= describe( $self->mime_type() );

    return $desc;
}

{
    my %browser_image = map { $_ => 1 } qw( image/gif image/jpeg image/png );

    sub _build_is_browser_displayable_image {
        return $browser_image{ $_[0]->mime_type() };
    }
}

{
    my @displayable = (
        qr{^text/},
        qr{^application/ecmascript$},
        qr{^application/javascript$},
        qr{^application/x-httpd-php.*},
        qr{^application/x-perl$},
        qr{^application/x-ruby$},
        qr{^application/x-shellscript$},
        qr{^application/sgml},
        qr{^application/xml},
        qr{^application/.+\+xml$}
    );

    sub _build_is_displayable_in_browser {
        my $self = shift;

        my $type = $self->mime_type();

        return $self->is_browser_displayable_image()
            || any { $type =~ $_ } @displayable;
    }
}

sub _build_file_on_disk {
    my $self = shift;

    my $dir = Silki::Config->new()->files_dir();

    my $file = $dir->file( $self->_filename_with_hash() );

    return $file
        if -f $file
            && ( File::stat::populate( CORE::stat(_) ) )->mtime()
            >= $self->creation_datetime()->epoch();

    open my $fh, '>', $file;
    print {$fh} $self->contents();
    close $fh;

    return $file;
}

sub _build_small_image_file {
    my $self = shift;

    return unless $self->is_browser_displayable_image();

    my $dir = Silki::Config->new()->small_image_dir();

    my $file = $dir->file( $self->_filename_with_hash() );

    return $file
        if -f $file
            && ( File::stat::populate( CORE::stat(_) ) )->mtime()
            >= $self->creation_datetime()->epoch();

    Image::Thumbnail->new(
        module     => 'Image::Magick',
        size       => '150x400',
        create     => 1,
        inputpath  => $self->file_on_disk()->stringify(),
        outputpath => $file->stringify(),
    );

    return $file;
}

sub _build_thumbnail_file {
    my $self = shift;

    return unless $self->is_browser_displayable_image();

    my $dir = Silki::Config->new()->thumbnails_dir();

    my $file = $dir->file( $self->_filename_with_hash() );

    return $file
        if -f $file
            && ( File::stat::populate( CORE::stat(_) ) )->mtime()
            >= $self->creation_datetime()->epoch();

    Image::Thumbnail->new(
        module     => 'Image::Magick',
        size       => '75x200',
        create     => 1,
        inputpath  => $self->file_on_disk()->stringify(),
        outputpath => $file->stringify(),
    );

    return $file;
}

sub _build_filename_with_hash {
    my $self = shift;

    return join q{-},
        sha256_hex( $self->file_id(), Silki::Config->new()->secret() ),
        $self->filename();
}

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: Represents a file

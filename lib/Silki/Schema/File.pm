package Silki::Schema::File;

use strict;
use warnings;

use autodie;
use Digest::SHA qw( sha256_hex );
use File::MimeInfo qw( describe );
use File::stat;
use Image::Magick;
use Image::Thumbnail;
use Silki::Config;
use Silki::Schema;
use Silki::Types qw( Str Bool File Maybe );

use Fey::ORM::Table;

with 'Silki::Role::Schema::URIMaker';

my $Schema = Silki::Schema->Schema();

has_policy 'Silki::Schema::Policy';

has_table( $Schema->table('File') );

has_one( $Schema->table('User') );

has_one( $Schema->table('Wiki') );

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

has thumbnail_file => (
    is       => 'ro',
    isa      => Maybe[File],
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_thumbnail_file',
);

has _file_name_with_hash => (
    is       => 'ro',
    isa      => Str,
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_file_name_with_hash',
);

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

sub _build_is_displayable_in_browser {
    my $self = shift;

    return $self->is_browser_displayable_image()
        || $self->mime_type() =~ m{^text/};
}

sub _build_file_on_disk {
    my $self = shift;

    my $dir = Silki::Config->new()->files_dir();

    my $file = $dir->file( $self->_file_name_with_hash() );

    return $file
        if -f $file
            && ( File::stat::populate( CORE::stat(_) ) )->mtime()
            >= $self->creation_datetime()->epoch();

    open my $fh, '>', $file;
    print {$fh} $self->contents();
    close $fh;

    return $file;
}

sub _build_thumbnail_file {
    my $self = shift;

    return unless $self->is_browser_displayable_image();

    my $dir = Silki::Config->new()->thumbnails_dir();

    my $file = $dir->file( $self->_file_name_with_hash() );

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

sub _build_file_name_with_hash {
    my $self = shift;

    return join q{-},
        sha256_hex( $self->file_id(), Silki::Config->new()->secret() ),
        $self->file_name();
}

no Fey::ORM::Table;

__PACKAGE__->meta()->make_immutable();

1;

__END__

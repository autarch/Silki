package Silki::Schema::File;

use strict;
use warnings;

use autodie;
use File::MimeInfo qw( describe );
use Image::Magick;
use Image::Thumbnail;
use Silki::Schema;
use Silki::Types qw( HashRef Str Bool );

use Fey::ORM::Table;

with 'Silki::Role::Schema::URIMaker';

my $Schema = Silki::Schema->Schema();

has_policy 'Silki::Schema::Policy';

has_table( $Schema->table('File') );

has_one( $Schema->table('User') );

has_one( $Schema->table('Wiki') );

has is_browser_displayable_image => (
    is       => 'ro',
    isa      => Bool,
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_is_browser_displayable_image',
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

sub thumbnail_file {
    my $self = shift;

    use File::Temp qw( tempdir );
    my $dir = tempdir( CLEANUP => 1 );

    my $file = "$dir/" . $self->file_name();

    return $file if -f $file;

    Image::Thumbnail->new(
        module     => 'Image::Magick',
        size       => '75x200',
        create     => 1,
        input      => $self->file_on_disk(),
        outputpath => $file,
    );

    return $file;
}

sub file_on_disk {
    my $self = shift;

    use File::Temp qw( tempdir );
    my $dir = tempdir( CLEANUP => 1 );

    my $file = "$dir/" . $self->file_name();

    open my $fh, '>', $file;
    print {$fh} $self->contents();
    close $fh;

    return $file;
}

no Fey::ORM::Table;

__PACKAGE__->meta()->make_immutable();

1;

__END__

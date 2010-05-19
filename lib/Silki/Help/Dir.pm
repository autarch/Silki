package Silki::Help::Dir;

use strict;
use warnings;
use namespace::autoclean;

use Silki::Config;
use Silki::Help::File;
use Silki::Types qw( ArrayRef Str );

use Moose;

has locale_code => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

has _files => (
    traits   => ['Array'],
    is       => 'ro',
    isa      => ArrayRef ['Silki::Help::File'],
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_files',
    handles  => { files => 'elements' },
);

has content => (
    is       => 'ro',
    isa      => Str,
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_content',
);

# XXX - need some sane locale fallback, and possibly also handling of partial
# translations.
sub _build_files {
    my $self = shift;

    my $help_dir = Silki::Config->new()->share_dir()->subdir('help');

    my $lang_dir = $help_dir->subdir( $self->locale_code() );

    die "No $lang_dir exists (bad locale?)"
        unless -d $lang_dir;

    return [
        map {
            Silki::Help::File->new(
                file        => $_,
                locale_code => $self->locale_code(),
                )
            }
        sort { $a cmp $b }
        grep { !$_->is_dir() } $lang_dir->children()
    ];
}

sub _build_content {
    my $self = shift;

    return join "\n", map { $_->content() } $self->files();
}

__PACKAGE__->meta()->make_immutable();

1;

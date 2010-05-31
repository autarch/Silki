package Silki::Help::Dir;

use strict;
use warnings;
use namespace::autoclean;

use Silki::Config;
use Silki::Help::File;
use Silki::Types qw( ArrayRef Str );
use Text::TOC::HTML;

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

my $toc_filter = sub {
    my $node = shift;

    return if $node->parentNode()->className() =~ /markdown-output/;

    return $node->tagName() =~ /^h[2-4]$/i;
};

sub _build_content {
    my $self = shift;

    my $toc = Text::TOC::HTML->new( filter => $toc_filter );

    $toc->add_file(
        file    => $_->file(),
        content => $_->content(),
    ) for $self->files();

    my $page = $toc->html_for_toc();
    $page .= "\n";
    $page .= join "\n",
        map { $toc->html_for_document( $_->file() ) } $self->files();

    $page =~ s{<html><head></head><body>(.+)</body></html>}{$1}s;

    return $page;
}

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: A directory of help files

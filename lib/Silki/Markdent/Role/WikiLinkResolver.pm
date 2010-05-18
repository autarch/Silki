package Silki::Markdent::Role::WikiLinkResolver;

use strict;
use warnings;

our $VERSION = '0.01';

use Silki::I18N qw( loc );

use namespace::autoclean;
use Moose::Role;

has _wiki => (
    is       => 'ro',
    isa      => 'Silki::Schema::Wiki',
    required => 1,
    init_arg => 'wiki',
);

sub _resolve_page_link {
    my $self         = shift;
    my $link         = shift;
    my $display_text = shift;

    my $wiki       = $self->_wiki();
    my $page_title = $link;

    if ( $link =~ m{^([^/]+)/([^/]+)$} ) {
        $wiki = Silki::Schema::Wiki->new( short_name => $1 )
            or return;

        $page_title = $2;
    }

    my $page = $self->_page_for_title( $page_title, $wiki );

    unless ( defined $display_text ) {
        $display_text = $self->_link_text_for_page(
            $wiki,
            ( $page ? $page->title() : $page_title ),
        );
    }

    return {
        page  => $page,
        title => $page_title,
        text  => $display_text,
        wiki  => $wiki,
    };
}

sub _link_text_for_page {
    my $self       = shift;
    my $wiki       = shift;
    my $page_title = shift;

    my $text = $page_title;

    $text .= ' (' . $wiki->title() . ')'
        unless $wiki->wiki_id() == $self->_wiki()->wiki_id();

    return $text;
}

sub _page_for_title {
    my $self  = shift;
    my $title = shift;
    my $wiki  = shift;

    return Silki::Schema::Page->new(
        title   => $title,
        wiki_id => $wiki->wiki_id(),
    ) || undef;
}

sub _resolve_file_link {
    my $self         = shift;
    my $file_id      = shift;
    my $display_text = shift;

    my $wiki = $self->_wiki();

    if ( $file_id =~ m{^([^/]+)/file:([^/]+)$} ) {
        $wiki = Silki::Schema::Wiki->new( short_name => $1 )
            or return;

        $file_id = $2;
    }
    else {
        $file_id =~ s/^file://;
    }

    my $file = Silki::Schema::File->new( file_id => $file_id );

    unless ( defined $display_text ) {
        $display_text = $self->_link_text_for_file(
            $wiki,
            $file,
            $file_id,
        );
    }

    return {
        file => $file,
        text => $display_text,
        wiki => $wiki,
    };
}

sub _link_text_for_file {
    my $self = shift;
    my $wiki = shift;
    my $file = shift;

    return loc('(Link to non-existent file)') unless $file;

    my $text = $file->file_name();

    $text .= ' (' . $wiki->title() . ')'
        unless $wiki->wiki_id() == $self->_wiki()->wiki_id();

    return $text;
}

# These classes may in turn load other classes which use this role, so they
# need to be loaded after the role is defined.
require Silki::Schema::File;
require Silki::Schema::Page;
require Silki::Schema::Wiki;

1;

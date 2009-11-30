package Silki::Markdent::Handler::HTMLStream;

use strict;
use warnings;

our $VERSION = '0.01';

use MooseX::Params::Validate qw( validated_list );
use Silki::I18N qw( loc );
use Silki::Schema::Page;
use Silki::Schema::Permission;
use Silki::Types qw( Bool Str );

use namespace::autoclean;
use Moose;
use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;

extends 'Markdent::Handler::HTMLStream';

with 'Silki::Markdent::Role::WikiLinkResolver';

has '+title' => (
    required => 0,
);

has for_editor => (
    is      => 'ro',
    isa     => Bool,
    default => 0,
);

has _user => (
    is       => 'ro',
    isa      => 'Silki::Schema::User',
    required => 1,
    init_arg => 'user',
);

# We don't want to generate a complete HTML document
sub start_document { }
sub end_document   { }

sub wiki_link {
    my $self = shift;
    my ( $link, $display_text ) = validated_list(
        \@_,
        link_text    => { isa => Str },
        display_text => { isa => Str, optional => 1 },

    );

    my $link_data = $self->_resolve_link( $link, $display_text );

    return unless $link_data;

    return exists $link_data->{file}
        ? $self->_link_to_file($link_data)
        : $self->_link_to_page($link_data);
}

sub _link_to_file {
    my $self = shift;
    my $p    = shift;

    my $file = $p->{file};

    unless ( defined $file ) {
        $self->_stream()->text( $p->{text} );
        return;
    }

    unless (
        $self->_user()->has_permission_in_wiki(
            wiki       => $file->wiki(),
            permission => Silki::Schema::Permission->Read(),
        )
        ) {

        $self->_stream()->text( loc('Inaccessible file') );
        return;
    }

    my $file_uri = $file->uri();

    my $dl = loc("Download this file");

    $self->_stream()->tag( a => ( href => $file_uri, title => $dl ) );
    $self->_stream()->text( $p->{text} );
    $self->_stream()->tag( '_a' );
}

sub _link_to_page {
    my $self = shift;
    my $p    = shift;

    my $page = $p->{page};

    if ( $self->for_editor() ) {
        $page ||= Silki::Schema::Page->new(
            page_id     => 0,
            wiki_id     => $p->{wiki}->wiki_id(),
            title       => $p->{title},
            uri_path    => Silki::Schema::Page->TitleToURIPath( $p->{title} ),
            _from_query => 1,
        );
    }

    my $uri
        = $page
        ? $page->uri()
        : $p->{wiki}->uri( view => 'new_page_form', query => { title => $p->{title} } );

    my $class = $page ? 'existing-page' : 'new-page';

    $self->_stream()->tag( a => ( href => $uri, class => $class ) );
    $self->_stream()->text( $p->{text} );
    $self->_stream()->tag( '_a' );

}

1;

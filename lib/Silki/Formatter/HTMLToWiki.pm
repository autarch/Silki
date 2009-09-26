package Silki::Formatter::HTMLToWiki;

use strict;
use warnings;

use HTML::WikiConverter;
use HTML::WikiConverter::SilkiMM;
use HTML::Entities qw( encode_entities );
use URI;

use Moose;
use MooseX::StrictConstructor;

has _user => (
    is       => 'ro',
    isa      => 'Silki::Schema::User',
    required => 1,
    init_arg => 'user',
);

has _wiki => (
    is       => 'ro',
    isa      => 'Silki::Schema::Wiki',
    required => 1,
    init_arg => 'wiki',
);

has _converter => (
    is      => 'ro',
    isa     => 'HTML::WikiConverter::SilkiMM',
    lazy    => 1,
    builder => '_build_converter',
);

sub html_to_wikitext {
    my $self = shift;
    my $html = shift;

    my $wiki_uri = URI->new( $self->_wiki()->domain()->uri() )->path();
    $wiki_uri .= '/page';

    my $wikitext = $self->_converter->html2wiki(
        $html,
        wiki_uri   => [qr{\Q$wiki_uri\E([^/]+)}],
        link_style => 'inline',
    );

    $wikitext =~ s{<br\s*/?>}{}g;

    return $wikitext;
}

sub _build_converter {
    my $self = shift;

    return HTML::WikiConverter->new( dialect => 'SilkiMM' );
}

no Moose;

__PACKAGE__->meta()->make_immutable();

1;

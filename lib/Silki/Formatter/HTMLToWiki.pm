package Silki::Formatter::HTMLToWiki;

use strict;
use warnings;

use HTML::WikiConverter;
use HTML::WikiConverter::SilkiMM;
use HTML::Entities qw( encode_entities );
use Silki::Formatter::WikiToHTML;
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

    my $wikitext = $self->_converter->html2wiki(
        $html,
        wiki_uri => [qr{(^/wiki/.+)}],
    );

    $wikitext .= "\n"
        unless $wikitext =~ /\n$/s;

    return $wikitext;
}

sub _build_converter {
    my $self = shift;

    my $formatter = Silki::Formatter::WikiToHTML->new(
        user => $self->_user(),
        wiki => $self->_wiki(),
    );

    return HTML::WikiConverter->new(
        dialect            => 'SilkiMM',
        wiki               => $self->_wiki(),
        wikitext_formatter => $formatter,
        link_style         => 'inline',
    );
}

no Moose;

__PACKAGE__->meta()->make_immutable();

1;

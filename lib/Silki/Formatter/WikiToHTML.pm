package Silki::Formatter::WikiToHTML;

use strict;
use warnings;
use namespace::autoclean;

use Markdent::Handler::HTMLFilter;
use Markdent::Handler::Multiplexer;
use Markdent::Parser;
use Silki::Markdent::Dialect::Silki::BlockParser;
use Silki::Markdent::Dialect::Silki::SpanParser;
use Silki::Markdent::Handler::HTMLGenerator;
use Silki::Types qw( Bool );

use Moose;
use MooseX::StrictConstructor;

has _user => (
    is       => 'ro',
    isa      => 'Silki::Schema::User',
    required => 1,
    init_arg => 'user',
);

has _page => (
    is       => 'ro',
    isa      => 'Silki::Schema::Page',
    init_arg => 'page',
);

has _wiki => (
    is       => 'ro',
    isa      => 'Silki::Schema::Wiki',
    required => 1,
    init_arg => 'wiki',
);

has _include_toc => (
    is       => 'ro',
    isa      => Bool,
    init_arg => 'include_toc',
    default  => 0,
);

has _for_editor => (
    is       => 'ro',
    isa      => Bool,
    init_arg => 'for_editor',
    default  => 0,
);

sub captured_events_to_html {
    my $self     = shift;
    my $captured = shift;

    my $generator = sub { $captured->replay_events( $_[0] ) };

    return $self->_generate_html($generator);
}

sub wiki_to_html {
    my $self = shift;
    my $text = shift;

    my $generator = sub {
        my $filter = Markdent::Handler::HTMLFilter->new( handler => $_[0] );

        my $parser = Markdent::Parser->new(
            dialect => 'Silki::Markdent::Dialect::Silki',
            handler => $filter,
        );

        $parser->parse( markdown => $text );
    };

    return $self->_generate_html($generator);
}

sub _generate_html {
    my $self      = shift;
    my $generator = shift;

    my $html = Silki::Markdent::Handler::HTMLGenerator->new(
        wiki        => $self->_wiki(),
        user        => $self->_user(),
        include_toc => $self->_include_toc(),
        for_editor  => $self->_for_editor(),
    );

    $generator->($html);

    return $html->final_html_output();
}

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: Turns wikitext into HTML

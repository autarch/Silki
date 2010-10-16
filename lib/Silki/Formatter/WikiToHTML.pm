package Silki::Formatter::WikiToHTML;

use strict;
use warnings;
use namespace::autoclean;

use Encode qw( decode );
use Markdent::Handler::HTMLFilter;
use Markdent::Handler::Multiplexer;
use Markdent::Parser;
use Silki::Markdent::Dialect::Silki::BlockParser;
use Silki::Markdent::Dialect::Silki::SpanParser;
use Silki::Markdent::Handler::ExtractWikiLinks;
use Silki::Markdent::Handler::HeaderCount;
use Silki::Markdent::Handler::HTMLStream;
use Silki::Types qw( Bool );
use Text::TOC::HTML;

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

    return $self->_generate_and_process_html($generator);
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

    return $self->_generate_and_process_html($generator);
}

sub _generate_and_process_html {
    my $self = shift;

    return $self->_process_html( $self->_generate_html(@_) );
}

sub _generate_html {
    my $self      = shift;
    my $generator = shift;

    my $buffer = q{};
    open my $fh, '>:utf8', \$buffer;

    my $html = Silki::Markdent::Handler::HTMLStream->new(
        output     => $fh,
        wiki       => $self->_wiki(),
        user       => $self->_user(),
        for_editor => $self->_for_editor(),
    );

    my $final_handler = $html;
    my $counter;

    if ( $self->_include_toc() ) {
        $counter = Silki::Markdent::Handler::HeaderCount->new();
        $final_handler = Markdent::Handler::Multiplexer->new( handlers => [ $html, $counter ] );
    }

    $generator->($final_handler);

    return ( $buffer, $counter );
}

sub _process_html {
    my $self    = shift;
    my $html    = shift;
    my $counter = shift;

    return decode( 'utf-8', $html )
        unless $counter && $counter->count() > 2;

    $html = decode( 'utf-8', $html );

    my $toc = Text::TOC::HTML->new(
        filter => sub { $_[0]->tagName() =~ /^h[1-4]$/i } );

    my $fake_file = $self . q{};
    $toc->add_file( file => $fake_file, content => $html );

    return
          q{<div id="table-of-contents">} . "\n"
        . $toc->html_for_toc() . "\n"
        . '</div>' . "\n"
        . $toc->html_for_document($fake_file);
}

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: Turns wikitext into HTML

package Silki::Formatter::WikiToHTML;

use strict;
use warnings;

use HTML::Entities qw( encode_entities );
use Silki::Schema::Page;
use Text::MultiMarkdown;

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

has _tmm => (
    is       => 'ro',
    isa      => 'Text::MultiMarkdown',
    lazy     => 1,
    default  => sub { Text::MultiMarkdown->new() },
    init_arg => undef,
);

sub wikitext_to_html {
    my $self = shift;
    my $text = shift;

    $text = $self->_handle_wiki_links($text);

    return $self->_tmm()->markdown($text);
}

my $link_re = qr/\[\[([^\]]+?)\]\]/;

sub _handle_wiki_links {
    my $self = shift;
    my $text = shift;

    $text =~ s/$link_re/$self->_link_to_page($1)/eg;

    return $text;
}

sub _link_to_page {
    my $self  = shift;
    my $title = shift;

    my $page = $self->_page_for_title($title);

    my $class = $page ? 'existing-page' : 'new-page';

    my $uri
        = $page
        ? $page->uri()
        : $self->_wiki()
        ->uri( view => 'new_page_form', query => { title => $title } );

    my $escaped_title = encode_entities($title);

    return qq{<a href="$uri" class="$class">$escaped_title</a>};
}

sub links {
    my $self = shift;
    my $text = shift;

    my %links = map {
        $_ => {
            page => $self->_page_for_title($_),
            wiki => $self->_wiki(),
            }
    } ( $text =~ /$link_re/g );

    return \%links;
}

sub _page_for_title {
    my $self  = shift;
    my $title = shift;

    return Silki::Schema::Page->new(
        title   => $title,
        wiki_id => $self->_wiki()->wiki_id(),
    ) || undef;
}

no Moose;

__PACKAGE__->meta()->make_immutable();

1;

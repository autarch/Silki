package Silki::Formatter;

use strict;
use warnings;

use HTML::Entities qw( encode_entities );
use Silki::Schema::Page;
use Text::MultiMarkdown;

use Moose;
use MooseX::StrictConstructor;

has _user =>
    ( is       => 'ro',
      isa      => 'Silki::Schema::User',
      required => 1,
      init_arg => 'user',
    );

has _wiki =>
    ( is       => 'ro',
      isa      => 'Silki::Schema::Wiki',
      required => 1,
      init_arg => 'wiki',
    );

has _tmm =>
    ( is       => 'ro',
      isa      => 'Text::MultiMarkdown',
      lazy     => 1,
      default  => sub { Text::MultiMarkdown->new() },
      init_arg => undef,
    );

sub wikitext_to_html
{
    my $self = shift;
    my $text = shift;

    $text = $self->_handle_wiki_links($text);

    return $self->_tmm()->markdown($text);
}

sub _handle_wiki_links
{
    my $self = shift;
    my $text = shift;

    $text =~ s/\[\[([^\]]+?)\]\]/$self->_link_to_page($1)/eg;

    return $text;
}

sub _link_to_page
{
    my $self  = shift;
    my $title = shift;

    my $page =
        Silki::Schema::Page->new( title   => $title,
                                  wiki_id => $self->_wiki()->wiki_id(),
                                );

    my $class = $page ? 'existing-page' : 'new-page';
    my $uri = $page ? $page->uri() : q{};

    my $escaped_title = encode_entities($title);

    return qq{<a href="$uri" class="$class">$escaped_title</a>};
}

no Moose;

__PACKAGE__->meta()->make_immutable();

1;

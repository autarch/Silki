package Silki::Markdent::Dialect::Silki::SpanParser;

use strict;
use warnings;

our $VERSION = '0.01';

use List::AllUtils qw( insert_after_string );
use Silki::Markdent::Event::WikiLink;

use namespace::autoclean;
use Moose;
use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;

extends 'Markdent::Dialect::Theory::SpanParser';

sub _possible_span_matches {
    my $self = shift;

    my @look_for = $self->SUPER::_possible_span_matches(@_);

    # inside code span
    return @look_for if @look_for == 1;

    insert_after_string 'code_start', 'wiki_link', @look_for;

    return @look_for;
}

# Stolen from Text::Markdown
my $nested_curlies;
$nested_curlies = qr{
    (?>                                 # Atomic matching
       [^{}]+                           # Anything other than parens
       |
       \{
         (??{ $nested_curlies })        # Recursive set of nested curlies
       \}
    )*
}x;

sub _match_wiki_link {
    my $self = shift;
    my $text = shift;

    return unless ${$text} =~ / \G
                                \[\[
                                ([^]]+)
                                \]\]
                                (?:
                                  \{
                                   ($nested_curlies)
                                  \}
                                )?
                              /xmgc;

    my %p = ( link_text => $1 );
    $p{display_text} = $2
        if defined $2;

    my $event = $self->_make_event( 'Silki::Markdent::Event::WikiLink' => %p );

    $self->_markup_event($event);

    return 1;
}

__PACKAGE__->meta()->make_immutable();

1;

package Silki::Markdent::Dialect::Silki::SpanParser;

use strict;
use warnings;

our $VERSION = '0.01';

use List::AllUtils qw( insert_after_string );
use Silki::Markdent::Event::FileLink;
use Silki::Markdent::Event::ImageLink;
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

    for my $val (qw( image_link file_link wiki_link )) {
        insert_after_string 'code_start', $val, @look_for;
    }

    return @look_for;
}

# More or less stolen from Text::Markdown
my $nested_brackets;
$nested_brackets = qr{
    (?>                                 # Atomic matching
       [^\[\]]+                           # Anything other than brackets
       |
       \[
         (??{ $nested_brackets })        # Recursive set of nested curlies
       \]
    )*
}x;

sub _match_wiki_link {
    my $self = shift;
    my $text = shift;

    return unless ${$text} =~ / \G
                                (?:
                                  \{
                                  ($nested_brackets)
                                  \}
                                )?
                                \(\(
                                ([^]]+)
                                \)\)
                              /xmgc;

    my %p = ( link_text => $1 );
    $p{display_text} = $2
        if defined $2;

    my $event = $self->_make_event( 'Silki::Markdent::Event::WikiLink' => %p );

    $self->_markup_event($event);

    return 1;
}

sub _match_file_link {
    my $self = shift;
    my $text = shift;

    my ( $display_text, $arg ) = $self->_parse_wiki_command( $text, 'file' )
        or return;

    my %p = ( link_text => $arg );
    $p{display_text} = $display_text if defined $display_text;

    my $event = $self->_make_event( 'Silki::Markdent::Event::FileLink' => %p );

    $self->_markup_event($event);

    return 1;
}

sub _match_image_link {
    my $self = shift;
    my $text = shift;

    my ( $display_text, $arg ) = $self->_parse_wiki_command( $text, 'file' )
        or return;

    my %p = ( link_text => $arg );
    $p{display_text} = $display_text if defined $display_text;

    my $event = $self->_make_event( 'Silki::Markdent::Event::ImageLink' => %p );

    $self->_markup_event($event);

    return 1;
}

sub _parse_wiki_command {
    my $self    = shift;
    my $text    = shift;
    my $command = shift;

    return unless ${$text} =~ / \G
                                (?:
                                  \[
                                  ($nested_brackets)
                                  \]
                                )?
                                {{
                                \s*
                                \Q$command\E:
                                \s*
                                ([^}]+)
                                \s*
                                }}
                              /xmgc;

    return ( $1, $2 );
}

__PACKAGE__->meta()->make_immutable();

1;

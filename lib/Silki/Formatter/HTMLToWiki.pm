package Silki::Formatter::HTMLToWiki;

use strict;
use warnings;
use namespace::autoclean;

use HTML::TreeBuilder;
use IO::Handle;
use Markdent::Types qw( OutputStream );
use Silki::Formatter::HTMLToWiki::Table;
use Silki::Types qw( Maybe Str ArrayRef PosOrZeroInt Bool );
use Silki::Util qw( string_is_empty );
use URI;

use Moose;
use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;

has _wiki => (
    is       => 'ro',
    isa      => 'Silki::Schema::Wiki',
    required => 1,
    init_arg => 'wiki',
);

has _stream => (
    is       => 'rw',
    isa      => OutputStream,
    init_arg => undef,
);

has _last_output_was_newline => (
    is      => 'rw',
    isa     => Bool,
    default => 0,
);

has _indent_level => (
    traits  => ['Counter'],
    is      => 'rw',
    isa     => PosOrZeroInt,
    default => 0,
    handles => {
        _inc_indent_level => 'inc',
        _dec_indent_level => 'dec',
    },
    init_arg => undef,
);

has _bullet_stack => (
    traits  => ['Array'],
    is      => 'bare',
    isa     => ArrayRef [Str],
    default => sub { [] },
    handles => {
        _push_bullet => 'push',
        _pop_bullet  => 'pop',
        _bullet      => [ get => -1 ],
    },
);

has _current_href => (
    is  => 'rw',
    isa => Maybe[Str],
);

has _table => (
    is       => 'rw',
    isa      => 'Silki::Formatter::HTMLToWiki::Table',
    handles  => qr/^_(?:start|end)/,
    clearer  => '_clear_table',
    init_arg => undef,
);

sub html_to_wikitext {
    my $self = shift;
    my $html = shift;

    return q{} if string_is_empty($html);

    my $buffer = q{};
    $self->_replace_stream( \$buffer );

    my $tree = HTML::TreeBuilder->new();
    $tree->store_comments(1);

    $tree->parse_content($html);

    $self->_handle_events_from_tree($tree);

    $buffer .= "\n"
        unless $buffer =~ /\n$/s;

    return $buffer;
}

sub _replace_stream {
    my $self   = shift;
    my $buffer = shift;

    open my $fh, '>:utf8', $buffer;

    my $old_stream = $self->_stream();

    $self->_set_stream($fh);

    return $old_stream;
}

sub _handle_events_from_tree {
    my $self = shift;
    my $tree = shift;

    $tree->normalize_content();
    $tree->objectify_text();

    for my $node ( $tree->content_list() ) {
        my $handle = '_handle_' . $node->tag();
        if ( $self->can($handle) ) {
            $self->$handle($node);
            next;
        }

        # This will generate impossible names for pseudo-tags like ~text, but
        # the ->can check will just return false, so it's ok.
        my ( $start, $end ) = map { '_start_' . $_, '_end_' . $_ } $node->tag();

        $self->$start($node)
            if $self->can($start);

        $self->_handle_node($node);

        $self->_handle_events_from_tree($node);

        $self->$end($node)
            if $self->can($end);
    }
}

sub _handle_node {
    my $self = shift;
    my $node = shift;

    if ( $node->tag() eq '~text' ) {
        my $text = $node->attr('text');
        $text =~ s/\n+$//;

        $self->_print_to_stream($text);
    }
    elsif ( $node->tag() eq '~comment' ) {
        $self->_print_to_stream( '<!--' . $node->attr('text') . '-->' );
    }

    return;
}

for my $level ( 1..6 ) {
    my $start = sub {
        my $self = shift;
        $self->_print_to_stream( '#' x $level );
        $self->_print_to_stream( q{ } );
    };

    my $end = sub {
        my $self = shift;
        $self->_print_to_stream("\n\n");
    };

    __PACKAGE__->meta()->add_method( '_start_h' . $level => $start );
    __PACKAGE__->meta()->add_method( '_end_h' . $level => $end );
}

sub _start_strong {
    my $self = shift;

    $self->_print_to_stream('**');
}

sub _end_strong {
    my $self = shift;

    $self->_print_to_stream('**');
}

sub _start_em {
    my $self = shift;

    $self->_print_to_stream('_');
}

sub _end_em {
    my $self = shift;

    $self->_print_to_stream('_');
}

sub _start_code {
    my $self = shift;

    $self->_print_to_stream(q{`});
}

sub _end_code {
    my $self = shift;

    $self->_print_to_stream(q{`});
}

sub _handle_a {
    my $self = shift;
    my $node = shift;

    my $href = $node->attr('href');

    unless ( defined $href ) {
        $self->_handle_events_from_tree($node);
        return;
    }

    if ( $href =~ m{^/wiki/} ) {
        return $self->_handle_a_as_wiki_link( $node, $href );
    }
    else {
        return $self->_handle_a_as_external_link( $node, $href );
    }
}

sub _handle_a_as_wiki_link {
    my $self = shift;
    my $node = shift;
    my $href = shift;

    my $wiki;
    my $thing;
    my $default_text;

    if ( $href =~ m{^/wiki/([^/]+)/page/([^/]+)} ) {
        $wiki         = $1;
        $thing        = Silki::Schema::Page->URIPathToTitle($2);
        $default_text = $thing;
    }
    elsif ( $href =~ m{^/wiki/([^/]+)/file/([^/]+)} ) {
        $wiki  = $1;
        $thing = 'file:' . $2;

        my $file = Silki::Schema::File->new( file_id => $2 );

        $default_text = $file ? $file->filename() : q{};
    }
    else {
        return $self->_handle_a_as_external_link( $node, $href );
    }

    my $link = q{};
    if ( $wiki ne $self->_wiki()->short_name() ) {
        $link = $wiki . q{/};
    }

    $link .= $thing;

    my $buffer     = q{};
    my $old_stream = $self->_replace_stream( \$buffer );

    $self->_handle_events_from_tree($node);

    $buffer =~ s/^\s+|\s+$//g;

    $self->_set_stream($old_stream);

    $self->_print_to_stream( '[[' . $link . ']]' );
    $self->_print_to_stream( '{' . $buffer . '}' )
        unless $buffer eq $default_text;
}

sub _handle_a_as_external_link {
    my $self = shift;
    my $node = shift;
    my $href = shift;

    my $buffer     = q{};
    my $old_stream = $self->_replace_stream( \$buffer );

    $self->_handle_events_from_tree($node);

    $buffer =~ s/^\s+|\s+$//g;

    $self->_set_stream($old_stream);

    if ( $buffer eq $href ) {
        $self->_print_to_stream( '<' . $href . '>' );
    }
    else {
        $self->_print_to_stream( '[' . $buffer . ']' );
        $self->_print_to_stream( '(' . $href . ')' );
    }
}

# No need for _start_p
sub _end_p {
    my $self = shift;

    $self->_print_to_stream("\n\n");
}

sub _start_ul {
    my $self = shift;

    $self->_print_to_stream("\n")
        if defined $self->_bullet() && ! $self->_last_output_was_newline();
    $self->_push_bullet('*');
    $self->_inc_indent_level();
}

sub _end_ul {
    my $self = shift;

    $self->_pop_bullet();
    $self->_dec_indent_level();
    $self->_print_to_stream("\n")
        unless $self->_indent_level();
}

sub _start_ol {
    my $self = shift;

    $self->_print_to_stream("\n")
        if defined $self->_bullet() && ! $self->_last_output_was_newline();
    $self->_push_bullet('1.');
    $self->_inc_indent_level();
}

sub _end_ol {
    my $self = shift;

    $self->_pop_bullet();
    $self->_dec_indent_level();
    $self->_print_to_stream("\n")
        unless $self->_indent_level();
}

sub _start_li {
    my $self = shift;

    die "Attempt to start a list item but we are not in a list"
        unless defined $self->_bullet();

    $self->_print_to_stream( q{ } x ( 4 * ( $self->_indent_level() - 1 ) ) );
    $self->_print_to_stream( $self->_bullet() . q{ } );
}

sub _end_li {
    my $self = shift;
    $self->_print_to_stream("\n")
        unless $self->_last_output_was_newline();
}

sub _start_blockquote {
    my $self = shift;

    $self->_print_to_stream('> ')
}

sub _handle_table {
    my $self = shift;
    my $node = shift;

    my $table = Silki::Formatter::HTMLToWiki::Table->new();
    my $old_stream = $self->_stream();
    $self->_set_stream($table);
    $self->_set_table($table);

    $self->_handle_events_from_tree($node);

    $self->_clear_table();
    $self->_set_stream($old_stream);

    $table->finalize();

    $self->_print_to_stream( $table->as_markdown() );
    $self->_print_to_stream("\n");
}

sub _print_to_stream {
    my $self = shift;

    $self->_set_last_output_was_newline( $_[0] eq "\n" ? 1 : 0 );

    $self->_stream()->print( $_[0] );
}

__PACKAGE__->meta()->make_immutable();

1;

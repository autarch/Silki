package HTML::WikiConverter::SilkiMM;

use strict;
use warnings;

use HTML::Entities qw( decode_entities );
use List::AllUtils qw( all max );
use Params::Validate qw( ARRAYREF );

use Moose;
use MooseX::NonMoose;

extends 'HTML::WikiConverter::Markdown';

with 'Silki::Markdent::Role::WikiLinkResolver';

sub html2wiki {
    my $self = shift;

    # For some reason, HTML::WikiConvert insists on calling decode and encode
    # on the data you pass into it, which is just dumb, since if you _already_
    # have utf8 this breaks. We could call encode on the data before passing
    # it in, but that seems like a waste of work, so we just disable these
    # subs temporarily.
    no warnings 'redefine';
    local *HTML::WikiConverter::encode = sub { $_[1] };
    local *HTML::WikiConverter::decode = sub { $_[1] };

    return $self->SUPER::html2wiki(@_);
}

sub rules {
    my $self = shift;

    my $rules = $self->SUPER::rules(@_);

    return {
        %{$rules},
        table => {
            block => 1,
            start => \&_table_start,
            end   => \&_table_end,
        },
        tr => {
            start       => \&_tr_start,
            end         => \&_tr_end,
            line_format => 'multi'
        },
        td => {
            start       => \&_td_start,
            end         => \&_td_end,
            line_format => 'multi'
        },
        th => { alias   => 'td' },
        a  => { replace => \&_link },
        br => { replace => q{} },
        p  => {
            block       => 1,
            trim        => 'both',
            line_format => 'multi',
            line_prefix => \&_p_prefix
        },
    };
}

sub attributes {
    my $self = shift;

    return {
        %{ $self->SUPER::attributes() },
        strip_tags =>
            { type => ARRAYREF, default => [qw( ~comment script style / )] },
        wiki => { isa => 'Silki::Schema::Wiki', required => 1 },
    };
}

sub get_elem_contents {
    my ( $self, $node ) = @_;
    my $str = join '', map { $self->__wikify($_) } $node->content_list;

    if ( $self->{__in_table__} ) {
        $self->{__current_cell__}{content} .= $str;
    }
    else {
        return $str;
    }
}

sub _table_start {
    my $self = shift;
    warn "TABLE START\n";
    $self->{__in_table__} = 1;
    $self->{__rows__}     = [];

    return q{};
}

sub _tr_start {
    my $self = shift;
    warn "TR START\n";

    $self->{__current_row__} = [];

    return q{};
}

# This method is called for the first cell in a table, and before the
# first call to table or tr start!
sub _td_start {
    my $self = shift;
    my $node = shift;

    warn "TD START\n";

    $self->{__current_cell__} = {
        align => $node->attr('align') || q{},
        is_header_cell => ( $node->tag() eq 'th' ? 1 : 0 ),
        content => {},
    };

    return q{};
}

sub _td_end {
    my $self = shift;

    warn "TD END\n";

    $self->{__current_cell__}{content} =~ s/^\s+|\s+$//gm;

    push @{ $self->{__current_row__} }, $self->{__current_cell__};

    return q{};
}

sub _tr_end {
    my $self = shift;

    warn "TR END\n";

    push @{ $self->{__rows__} }, $self->{__current_row__};

    return q{};
}

sub _table_end {
    my $self = shift;

    warn "TABLE END\n";

    $self->{__in_table__} = 0;

    my @longest;

    for my $row ( @{ $self->{__rows__} } ) {
        for my $i ( 0 .. $#{$row} ) {
            my $length = max map {length} split /\n/, $row->[$i]{content};

            $longest[$i] ||= 0;
            $longest[$i] = $length
                if $length > $longest[$i];
        }
    }

    my $table = q{};

    for my $html_row ( @{ $self->{__rows__} } ) {
        $table .= $self->_html_row_to_wikitext( $html_row, \@longest );
    }

    $table .= "\n";

    return $table;
}

sub _html_row_to_wikitext {
    my $self     = shift;
    my $html_row = shift;
    my $longest  = shift;

    if ( !@{$html_row} ) {
        return "\n";
    }

    my $is_header = all { $_->{is_header_cell} } @{$html_row};

    my $wikitext = q{};

    my @wiki_rows;
    for my $i ( 0 .. $#{$html_row} ) {
        my $length = $longest->[$i] + 4;

        my $align = $html_row->[$i]{align} || 'left';

        my $format
            = $align eq 'left'   ? qq{ %${length}s   }
            : $align eq 'center' ? qq{  %${length}s  }
            :                      qq{   %${length}s };

        my @lines = split /\n/, $html_row->[$i]{content};
        for my $j ( 0 .. $#lines ) {
            $wiki_rows[$j][$i] = sprintf( $format, $lines[$j] );
        }
    }

    for my $j ( 0 .. $#wiki_rows ) {
        my $length = $longest->[$j] + 4;

        my $sep = $j ? q{:} : q{|};

        $wikitext .= $sep;
        $wikitext .= join $sep,
            map { defined $_ ? $_ : q{ } x $longest } @{ $wiki_rows[$j] };
        $wikitext .= $sep;

        $wikitext .= "\n";
    }

    if ($is_header) {
        $wikitext .= q{+};

        for my $j ( 0 .. $#wiki_rows ) {
            my $length = $longest->[$j] + 4;

            $wikitext .= q{-} x $length;

            $wikitext .= q{+};
        }
    }

    $wikitext .= "\n";

    return $wikitext;
}

sub _link {
    my ( $self, $node, $rules ) = @_;

    my $url = $node->attr('href') || '';
    my $text = decode_entities( $self->get_elem_contents($node) );
    $text =~ s/^\s+|\s+$//g;

    # CKEditor can leave behind things like <a href="..."> </a>.
    return unless defined $text && length $text;

    if ( my $path = $self->get_wiki_page($url) ) {
        if ( $path =~ m{ /wiki/([^/]+)/page/([^/]+) }x ) {
            return $self->_link_to_page( $1,
                Silki::Schema::Page->URIPathToTitle($2), $text );
        }
        elsif ( $path =~ m{ /wiki/([^/]+)/file/([^/]+)}x ) {
            return $self->_link_to_file( $1, $2, $text );
        }
        else {
            die 'wtf';
        }
    }
    else {
        return $self->SUPER::_link( $node, $rules );
    }
}

sub _link_to_page {
    my $self      = shift;
    my $wiki_name = shift;
    my $title     = shift;
    my $text      = shift;

    my $wiki;
    my $link;
    if ( $self->wiki()->short_name() eq $wiki_name ) {
        $link = '[[' . $title . ']]';
        $wiki = $self->wiki();
    }
    else {
        $link = '[[' . $wiki_name . q{/} . $title . ']]';
        $wiki = Silki::Schema::Wiki->new( short_name => $wiki_name )
            or return q{};
    }

    my $default_title = $self->_link_text_for_page( $wiki, $title );

    return $self->_link_plus_text( $link, $default_title, $text );
}

sub _link_to_file {
    my $self      = shift;
    my $wiki_name = shift;
    my $file_id   = shift;
    my $text      = shift;

    my $wiki;
    my $link;
    if ( $self->wiki()->short_name() eq $wiki_name ) {
        $link = '[[file:' . $file_id . ']]';
        $wiki = $self->wiki();
    }
    else {
        $link = '[[file:' . $wiki . q{/} . $file_id . ']]';
        $wiki = Silki::Schema::Wiki->new( short_name => $wiki_name )
            or return q{};
    }

    my $file = Silki::Schema::File->new( file_id => $file_id );
    my $default_title = $self->_link_text_for_file( $wiki, $file );

    return $self->_link_plus_text( $link, $default_title, $text );
}

sub _link_plus_text {
    my $self  = shift;
    my $link  = shift;
    my $title = shift;
    my $text  = shift;

    return $link if $text eq $title;

    return $link . '(' . $text . ')';
}

sub _p_prefix {
    my $self  = shift;
    my $node  = shift;
    my $rules = shift;

    # CKEditor uses 40px of margin-left per level of indentation
    if ( my $style = $node->attr('style') ) {
        if ( $style =~ /margin-left:\s+(\d+)px/ ) {
            return '> ' x ( $1 / 40 );
        }
    }

    return $self->SUPER::_p_prefix( $node, $rules );
}

__PACKAGE__->meta()->make_immutable( inline_constructor => 0 );

1;

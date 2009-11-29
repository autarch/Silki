package HTML::WikiConverter::SilkiMM;

use strict;
use warnings;

use HTML::Entities qw( decode_entities );
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
            end   => \&_table_end,
        },
        tr => {
            start       => \&_tr_start,
            end         => qq{ |\n},
            line_format => 'single'
        },
        td => {
            start => \&_td_start,
            end   => q{ }
        },
        th => { alias   => 'td', },
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

sub _table_end
{
    my $self = shift;

    delete $self->{__row_count__};
    delete $self->{__th_count__};

    return q{};
}


# This method is first called on the _second_ row, go figure
sub _tr_start
{
    my $self = shift;

    my $start = q{};
    if ( $self->{__row_count__} == 2 )
    {
        $start = '+----' x $self->{__th_count__};
        $start .= qq{+\n};
    }

    $self->{__row_count__}++;

    return $start;
}

# This method is called for the first cell in a table, and before the
# first call to table or tr start!
sub _td_start
{
    my $self = shift;

    $self->{__row_count__} = 1
        unless exists $self->{__row_count__};

    if ( $self->{__row_count__} == 1 )
    {
        if ( exists $self->{__th_count__} )
        {
            $self->{__th_count__}++;
        }
        else
        {
            $self->{__th_count__} = 1;
        }
    }

    return '| ';
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
            return $self->_link_to_page( $1, Silki::Schema::Page->URIPathToTitle($2), $text );
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

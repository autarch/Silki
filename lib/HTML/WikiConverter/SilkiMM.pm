package HTML::WikiConverter::SilkiMM;

use strict;
use warnings;

use base 'HTML::WikiConverter::MultiMarkdown';

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
        a => { replace => \&_link },
        p => {
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
        wiki => { isa => 'Silki::Schema::Wiki', required => 1 },
    };
}

sub _link {
    my ( $self, $node, $rules ) = @_;

    my $url = $node->attr('href') || '';

    if ( my $path = $self->get_wiki_page($url) ) {
        if ( $path =~ m{ /wiki/([^/]+)/page/([^/]+) }x ) {
            return $self->_link_to_page( $1, Silki::Schema::Page->URIPathToTitle($2) );
        }
        elsif ( $path =~ m{ /wiki/([^/]+)/file/([^/]+)}x ) {
            return $self->_link_to_file( $1, $2 );
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
    my $self  = shift;
    my $wiki  = shift;
    my $title = shift;

    if ( $self->wiki()->short_name() eq $wiki ) {
        return '[[' . $title . ']]';
    }
    else {
        return '[[' . $wiki . q{/} . $title . ']]';
    }
}

sub _link_to_file {
    my $self    = shift;
    my $wiki    = shift;
    my $file_id = shift;

    if ( $self->wiki()->short_name() eq $wiki ) {
        return '[[file:' . $file_id . ']]';
    }
    else {
        return '[[file:' . $wiki . q{/} . $file_id . ']]';
    }
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

1;

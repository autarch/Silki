package HTML::WikiConverter::SilkiMM;

use strict;
use warnings;

use base 'HTML::WikiConverter::MultiMarkdown';

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

sub _link {
    my ( $self, $node, $rules ) = @_;

    my $url = $node->attr('href') || '';

    if ( my $title = $self->get_wiki_page($url) ) {
        return '[[' . $title . ']]';
    }
    else {
        return $self->SUPER::_link( $node, $rules );
    }
}

sub _p_prefix {
    my $self = shift;
    my $node = shift;
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

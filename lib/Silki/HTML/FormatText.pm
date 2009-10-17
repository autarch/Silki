package Silki::HTML::FormatText;

use strict;
use warnings;

use base 'HTML::FormatText';

sub a_start {
    my $self  = shift;
    my $node  = shift;

    $self->{uri_for_a} = $node->attr('href');

    return 1;
}

sub a_end {
    my $self  = shift;
    my $node  = shift;

    $self->out( ' (' . $self->{uri_for_a} . ')' )
        if $self->{uri_for_a};

    delete $self->{uri_for_a};

    return 1;
}

1;

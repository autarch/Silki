package Silki::Web::Util;

use strict;
use warnings;

use Exporter qw( import );

our @EXPORT_OK = qw( format_note );

use Silki::Util qw( string_is_empty );
use Text::WikiFormat;

sub format_note {
    my $note = shift;

    return q{} if string_is_empty($note);

    return Text::WikiFormat::format(
        $note,
        {},
        {
            implicit_links => 0,
            extended       => 1,
            absolute_links => 1,
        }
    );
}

1;

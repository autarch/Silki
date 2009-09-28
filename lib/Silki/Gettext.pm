package Silki::Gettext;

use strict;
use warnings;

use HTML::Entities qw( encode_entities );
use Moose;

extends 'Data::Localize::Gettext';

sub load_from_file {
    my ( $self, $file ) = @_;

    print STDERR
        "[Data::Localize::Gettext]: load_from_file - loading from file $file\n"
        if &Data::Localize::DEBUG;
    my %lexicon;
    open( my $fh, '<', $file ) or die "Could not open $file: $!";

    # This stuff here taken out of Locale::Maketext::Lexicon, and
    # modified by daisuke
    my ( %var, $key, @comments, @ret, @metadata );
    my $UseFuzzy   = 0;
    my $KeepFuzzy  = 0;
    my $AllowEmpty = 1;    # XXX - overridden
    my @fuzzy;
    my $process = sub {
        $var{msgid} =~ s/\\\"/\"/g
            if defined $var{msgid};
        if (    length( $var{msgid} )
            and length( $var{msgstr} )
            and ( $UseFuzzy or !$var{fuzzy} ) ) {
            $lexicon{ $var{msgid} } = $var{msgstr};
        }
        elsif ($AllowEmpty) {

            # XXX - this is why this method is overridden
            $lexicon{ $var{msgid} } = $var{msgid};
        }
        if ( $var{msgid} eq '' ) {
            push @metadata, $self->parse_metadata( $var{msgstr} );
        }
        else {
            push @comments, $var{msgid}, $var{msgcomment};
        }
        if ( $KeepFuzzy && $var{fuzzy} ) {
            push @fuzzy, $var{msgid}, 1;
        }
        %var = ();
    };

    while (<$fh>) {
        $_ = Encode::decode( $self->encoding, $_, Encode::FB_CROAK() );
        s/[\015\012]*\z//;    # fix CRLF issues

        /^(msgid|msgstr) +"(.*)" *$/
            ? do {            # leading strings
            $key = $1;
            my $x = $2;
            $x =~ s/\\(n|\\)/
                $1 eq 'n' ? "\n" :
                            "\\" /gex;
            $var{$key} = $x;
            }
            :

            /^"(.*)" *$/
            ? do {            # continued strings
            $var{$key} .= $1;
            }
            :

            /^# (.*)$/
            ? do {            # user comments
            $var{msgcomment} .= $1 . "\n";
            }
            :

            /^#, +(.*) *$/
            ? do {            # control variables
            $var{$_} = 1 for split( /,\s+/, $1 );
            }
            :

            /^ *$/ && %var
            ? do {            # interpolate string escapes
            $process->($_);
            }
            : ();

    }

    # do not silently skip last entry
    $process->() if keys %var != 0;

    my $lang = File::Basename::basename($file);
    $lang =~ s/\.[mp]o$//;

    print STDERR "[Data::Localize::Gettext]: load_from_file - registering ",
        scalar keys %lexicon, " keys\n"
        if &Data::Localize::DEBUG;

    # This needs to be merged
    $self->lexicon_merge( $lang, \%lexicon );
}

sub format_string {
    my $self  = shift;
    my $value = shift;
    my @args  = @_;

    $value =~ s/%(\d+)/ defined $args[ $1 - 1 ] ? $args[ $1 - 1 ] : q{} /ge;
    $value =~ s/%(\w+)\(([^\)]+)\)/ $self->_method( $1, $2, \@args ) /ge;

    return $value;
}

sub _method {
    my $self     = shift;
    my $method   = shift;
    my $embedded = shift;
    my $args     = shift;

    my @embedded_args = split /,/, $embedded;

    return $self->$method( $args, \@embedded_args );
}

sub html {
    my $self = shift;
    my $args = shift;
    my $data = shift;

    return encode_entities( $data->[0] );
}

sub quant {
    my $self  = shift;
    my $args  = shift;
    my $forms = shift;

    my $num = shift @{$forms};
    $num += 0;

    die "quant can only be called with 2 or 3 forms"
        unless @{$forms} == 2 || @{$forms} == 3;

    return $forms->[2] if @{$forms} == 3 && $num == 0;

    return ( $self->number($num) . q{ }
            . ( $num == 1 ? $forms->[0] : $forms->[1] ) );
}

sub number {
    my $self = shift;
    my $num  = shift;

    return $num;
}

no Moose;

__PACKAGE__->meta()->make_immutable();

1;

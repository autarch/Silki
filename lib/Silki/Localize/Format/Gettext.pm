package Silki::Localize::Format::Gettext;

use strict;
use warnings;
use namespace::autoclean;

use feature ':5.10';

use DateTime::Locale;
use HTML::Entities qw( encode_entities );

use Moose;

extends 'Data::Localize::Format::Gettext';

sub html {
    my $self = shift;
    my $lang = shift;
    my $args = shift;

    return encode_entities( $args->[0] );
}

sub quant {
    my $self  = shift;
    my $lang  = shift;
    my $args  = shift;
    my @forms = @_;

    my $num = $args->[0];
    $num += 0;

    die "quant can only be called with 2 or 3 forms"
        unless @forms == 2 || @forms == 3;

    return $forms[2] if @forms == 3 && $num == 0;

    return (
        $self->_number($num) . q{ } . ( $num == 1 ? $forms[0] : $forms[1] ) );
}

sub _number {
    my $self = shift;
    my $args = shift;

    return $args->[0];
}

sub on_date {
    my $self = shift;
    my $lang = shift;
    my $args = shift;

    my $dt = $args->[0];

    my $day_key = $self->_day_key_for_dt($dt);

    my $id;

    given ($day_key) {
        when ('today')          { $id = loc('Today') }
        when ('yesterday')      { $id = loc('Yesterday') }
        when ('two_days_ago')   { $id = loc('Two days ago') }
        when ('three_days_ago') { $id = loc('Three days ago') }
        when ('any')            { $id = loc('on %date(%1)') }
        default { die "Unknown day key: $day_key" }
    }

    return $self->localize_for(
        lang => $lang,
        id   => $id,
        args => [$dt],
    );
}

sub on_datetime {
    my $self = shift;
    my $lang = shift;
    my $args = shift;

    my $dt = $args->[0];

    my $day_key = $self->_day_key_for_dt($dt);

    my $id;

    given ($day_key) {
        when ('today')          { $id = loc('Today %at_time(%1)') }
        when ('yesterday')      { $id = loc('Yesterday %at_time(%1)') }
        when ('two_days_ago')   { $id = loc('Two days ago %at_time(%1)') }
        when ('three_days_ago') { $id = loc('Three days ago %at_time(%1)') }
        when ('any')            { $id = loc('on %date(%1) %at_time(%1)') }
        default { die "Unknown day key: $day_key" }
    }

    return $self->localize_for(
        lang => $lang,
        id   => $id,
        args => [$dt],
    );
}

sub _day_key_for_dt {
    my $self = shift;
    my $dt   = shift;

    my $date = $dt->clone()->truncate( to => 'day' );

    my $cmp = DateTime->today( time_zone => $dt->time_zone() );

    return 'today' if $date eq $cmp;

    $cmp->subtract( days => 1 );

    return 'yesterday' if $date eq $cmp;

    $cmp->subtract( days => 1 );

    return 'two_days'
        if $date eq $cmp && $dt->locale()->relative_field_name( 'day', -2 );

    $cmp->subtract( days => 1 );

    return 'three_days'
        if $date eq $cmp && $dt->locale()->relative_field_name( 'day', -3 );

    return 'any';
}

sub date {
    my $self = shift;
    my $lang = shift;
    my $args = shift;

    my $dt = $args->[0];

    my $locale = DateTime::Locale->load($lang);

    my $today = DateTime->today( time_zone => $dt->time_zone() );

    my $format_dt = $dt->clone()->set( locale => $locale );

    my $cldr
        = $format_dt->year() eq $today->year()
        ? $locale->format_for('MMMd')
        : $locale->date_format_default();

    return $format_dt->format_cldr($cldr);
}

sub datetime {
    my $self = shift;
    my $lang = shift;
    my $args = shift;

    my $dt = $args->[0];

    my $day_key = $self->_day_key_for_dt($dt);

    my $id;

    given ($day_key) {
        when ('today')          { $id = loc('Today %at_time(%1)') }
        when ('yesterday')      { $id = loc('Yesterday %at_time(%1)') }
        when ('two_days_ago')   { $id = loc('Two days ago %at_time(%1)') }
        when ('three_days_ago') { $id = loc('Three days ago %at_time(%1)') }
        when ('any')            { $id = loc('%date(%1) %at_time(%1)') }
        default { die "Unknown day key: $day_key" }
    }

    return $self->localize_for(
        lang => $lang,
        id   => $id,
        args => [$dt],
    );
}

sub at_time {
    my $self = shift;
    my $lang = shift;
    my $args = shift;

    my $dt = $args->[0];

    return $self->localize_for(
        lang => $lang,
        id   => loc('at %time(%1)'),
        args => [$dt],
    );
}

sub time {
    my $self = shift;
    my $lang = shift;
    my $args = shift;

    my $dt = $args->[0];

    my $locale = DateTime::Locale->load($lang);

    my $format_dt = $dt->clone()->set( locale => $locale );

    my $cldr
        = $locale->prefers_24_hour_time()
        ? $locale->format_for('Hm')
        : $locale->format_for('hm');

    return $format_dt->format_cldr($cldr);
}

# This exists so that the extraction code finds the strings up above and
# sticks them in the .po files for translation.
sub loc { $_[0] }

__PACKAGE__->meta()->make_immutable();

1;

package Silki::Schema::TimeZone;

use strict;
use warnings;

use Fey::Object::Iterator::FromSelect;
use Silki::Schema;

use Fey::ORM::Table;

my $Schema = Silki::Schema->Schema();

{
    has_policy 'Silki::Schema::Policy';

    has_table( $Schema->table('TimeZone') );

    has_one( $Schema->table('Country') );
}

sub CreateDefaultZones {
    my $class = shift;

    my %zones = (
        us => [
            [ 'America/New_York',      'East Coast' ],
            [ 'America/Chicago',       'Midwest' ],
            [ 'America/Denver',        'Mountain' ],
            [ 'America/Los_Angeles',   'West Coast' ],
            [ 'America/Anchorage',     'Alaska (Anchorage, Juneau, Nome)' ],
            [ 'America/Adak',          'Alaska (Adak)' ],
            [ 'Pacific/Honolulu',      'Hawaii' ],
            [ 'America/Santo_Domingo', 'Puerto Rico' ],
            [ 'Pacific/Guam',          'Guam' ],
        ],

        ca => [
            [ 'America/Montreal',  'Quebec' ],
            [ 'America/Toronto',   'Ontario' ],
            [ 'America/Winnipeg',  'Manitoba' ],
            [ 'America/Regina',    'Sakatchewan' ],
            [ 'America/Edmonton',  'Alberta' ],
            [ 'America/Vancouver', 'British Columbia' ],
            [ 'America/St_Johns',  q{St. John's} ],
            [ 'America/Halifax',   'Halifax and New Brunswick' ],
        ],
    );

    for my $iso_code ( keys %zones ) {
        my $order = 1;

        for my $zone ( @{ $zones{$iso_code} } ) {
            next if $class->new( olson_name => $zone->[0] );

            $class->insert(
                olson_name    => $zone->[0],
                iso_code      => $iso_code,
                description   => $zone->[1],
                display_order => $order++,
            );
        }
    }
}

no Fey::ORM::Table;

__PACKAGE__->meta()->make_immutable();

1;

__END__


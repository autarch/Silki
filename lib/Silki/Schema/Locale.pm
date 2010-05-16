package Silki::Schema::Locale;

use strict;
use warnings;
use namespace::autoclean;

use DateTime::Locale;
use Silki::Schema;

use Fey::ORM::Table;

my $Schema = Silki::Schema->Schema();

{
    has_policy 'Silki::Schema::Policy';

    has_table( $Schema->table('Locale') );

    has_many countries => (
        table    => $Schema->table('Country'),
        order_by => [ $Schema->table('Country')->column('name'), 'ASC' ],
    );
}

sub CreateDefaultLocales {
    my $class = shift;

    for my $code ( DateTime::Locale->ids() ) {
        next if $class->new( locale_code => $code );

        $class->insert( locale_code => $code );
    }
}

__PACKAGE__->meta()->make_immutable();

1;

__END__

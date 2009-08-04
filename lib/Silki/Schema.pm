package Silki::Schema;

use strict;
use warnings;

use DBI;
use Fey::ORM::Schema;
use Fey::DBIManager::Source;
use Fey::Loader;


my $Schema;

{
    my $source =
        Fey::DBIManager::Source->new( dsn          => 'dbi:Pg:dbname=Silki',
                                      post_connect => \&_set_dbh_attributes,
                                    );

    $Schema = Fey::Loader->new( dbh => $source->dbh() )->make_schema();

    has_schema $Schema;

    __PACKAGE__->DBIManager()->add_source($source);
}

sub _set_dbh_attributes
{
    my $dbh = shift;

    $dbh->{pg_enable_utf8} = 1;

    $dbh->do( 'SET TIME ZONE UTC' );

    return;
}

no Fey::ORM::Schema;
no Moose;

__PACKAGE__->meta()->make_immutable();

1;

package Silki::Test;

use strict;
use warnings;

use Exporter qw(import);

our @EXPORT_OK = qw( mock_dbh );

use DBD::Mock 1.36;


sub mock_dbh
{
    require Silki::Schema;

    my $man = Silki::Schema->DBIManager();

    $man->remove_source('default');
    $man->add_source( name => 'default', dsn => 'dbi:Mock:' );

    return $man->default_source()->dbh();
}

1;

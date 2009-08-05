package Silki::Plugin::Session::Store::Silki;

use strict;
use warnings;

use base 'Catalyst::Plugin::Session::Store::DBI';

use Silki::Schema;


sub _session_dbic_connect
{
    my $self = shift;

    $self->_session_dbh( Silki::Schema->DBIManager()->default_source()->dbh() );
}

1;

use strict;
use warnings;

use lib 'inc';

use File::Slurp qw( read_file );
use File::Temp qw( tempdir );
use FindBin qw( $Bin );
use List::AllUtils qw( max );
use Path::Class qw( dir file );
use Silki::DBInstaller;

use Test::Differences;
use Test::More;

BEGIN {
    unless ( $ENV{RELEASE_TESTING} ) {
        require Test::More;
        Test::More::plan( skip_all => "These tests are for release testing" );
    }
}

my $testdir = dir($Bin);

my $min_version = 1;
my $max_version = max map { /\.v(\d+)/; $1 } glob "$testdir/*.v*";

my $inst
    = Silki::DBInstaller->new( name => 'SilkiMigrationTest', quiet => 1, );

my $tempdir = dir( tempdir( CLEANUP => 1 ) );

my %fresh;

for my $version ( $min_version .. $max_version ) {
    $inst->_drop_and_create_db();

    my $import_citext = $version >= 3 ? 1 : 0;
    $inst->_build_db(
        $testdir->file( 'Silki.sql.v' . $version ),
        $import_citext,
    );

    my $dump = $tempdir->file( 'fresh.v' . $version );

    _pg_dump( $inst, $dump );

    $fresh{$version} = $dump;
}

for my $version ( $min_version .. $max_version - 1 ) {
    $inst->_drop_and_create_db();

    my $import_citext = $version >= 3 ? 1 : 0;
    $inst->_build_db(
        $testdir->file( 'Silki.sql.v' . $version ),
        $import_citext,
    );

    for my $next_version ( $version + 1 .. $max_version ) {
        my $from_version = $next_version - 1;

        $inst->_migrate_db( $from_version, $next_version, 'no dump' );

        my $dump = $tempdir->file(
            sprintf( 'migrate.v%d-to-v%d', $from_version, $next_version ) );

        _pg_dump( $inst, $dump );

        _compare_files(
            $dump,
            $fresh{$next_version},
            $version,
            $next_version
        );
    }
}

done_testing();

sub _pg_dump {
    my $inst = shift;
    my $dump = shift;

    $inst->_run_pg_bin(
        command => 'pg_dump',
        flags   => [
            '-C', $inst->name(),
            '-f', $dump,
            '-s',
        ],
    );
}

sub _compare_files {
    my $migrated      = shift;
    my $fresh         = shift;
    my $start_version = shift;
    my $final_version = shift;

    eq_or_diff(
        scalar read_file( $migrated->stringify() ),
        scalar read_file( $fresh->stringify() ),
        "comparing migration from $start_version to $final_version"
    );
}

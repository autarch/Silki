package Silki::DBInstaller;

use strict;
use warnings;
use autodie qw( :all );

use lib 'lib';

use Fey::DBIManager::Source;
use File::Slurp qw( read_file);
use File::Temp qw( tempdir);
use Path::Class qw( file );

use Moose;
use MooseX::StrictConstructor;

with 'MooseX::Getopt';

has name => (
    is       => 'rw',
    writer   => '_set_name',
    isa      => 'Str',
    required => 1,
);

for my $attr (qw( username password host port )) {
    has $attr => (
        is     => 'rw',
        writer => '_set_' . $attr,
        isa    => 'Str',
    );
}

has _existing_config => (
    is      => 'ro',
    isa     => 'HashRef[Str]',
    lazy    => 1,
    builder => '_build_existing_config',
);

has db_exists => (
    is      => 'ro',
    isa     => 'Bool',
    lazy    => 1,
    builder => '_build_db_exists',
);

has drop => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

has seed => (
    is      => 'ro',
    isa     => 'Bool',
    default => 1,
);

has quiet => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

sub BUILD {
    my $self = shift;
    my $p    = shift;

    my $existing = $self->_existing_config();
    unless ( exists $p->{name} ) {
        die
            "No name provided to the constructor and no name available from an existing Silki config file."
            unless $existing->{name};

        $self->_set_name( $p->{name} );
    }

    for my $attr (qw( username password host port )) {
        my $set = '_set_' . $attr;

        $self->$set( $existing->{$attr} )
            if defined $existing->{$attr};
    }

    return;
}

sub run {
    my $self = shift;

    if ( !$self->drop() && $self->db_exists() ) {
        warn
            qq{\n  Will not drop a database unless you pass the --drop argument.\n\n};
        exit 1;
    }

    print "\n";
    $self->_drop_and_create_db();
    $self->_build_db();

    exit 0 unless $self->seed();

    $self->_seed_data();
}

sub update_or_install_db {
    my $self = shift;

    my $version = $self->_get_installed_version();

    print "\n";
    my $name = $self->name();
    $self->_msg("Installing/updating your Silki database (database name = $name).");

    if ( !defined $version ) {
        $self->_msg("Installing a fresh database.");
        $self->_drop_and_create_db();
        $self->_build_db();
        $self->_seed_data();
    }
    else {
        my $next_version = $self->_get_next_version();

        if ( $version == $next_version ) {
            $self->_msg("Your Silki database is up-to-date.");
            return;
        }

        $self->_msg(
            "Migrating your Silki database from version $version to $next_version."
        );

        $self->_migrate_db( $version, $next_version );
    }
}

sub _build_db_exists {
    my $self = shift;

    return $self->_make_dbh() ? 1 : 0;
}

sub _get_installed_version {
    my $self = shift;

    my $dbh = $self->_make_dbh()
        or return;

    my $row = $dbh->selectrow_arrayref(q{SELECT version FROM "Version"});

    return $row->[0] if $row;
}

sub _make_dbh {
    my $self   = shift;

    my $dsn = 'dbi:Pg:dbname=' . $self->name();

    $dsn .= ';host=' . $self->host()
        if defined $self->host();

    $dsn .= ';port=' . $self->port()
        if defined $self->port();

    my %source = ( dsn => $dsn );

    $source{username} = $self->username()
        if defined $self->username();

    $source{password} = $self->password()
        if defined $self->password();

    my $dbh = eval { Fey::DBIManager::Source->new(%source)->dbh() };

    die $@ if $@ and $@ !~ /database "\w+" does not exist/;

    return $dbh;
}

sub _build_existing_config {
    my $self = shift;

    require Silki::Config;

    my $instance = Silki::Config->instance();

    return {} unless $instance->config_file();

    return {
        map {
            my $attr = 'database_' . $key;
            $instance->$attr() ? ( $_ => $instance->$attr() ) : ()
            } qw( name username password host port )
    };
}

sub _get_next_version {
    my $self = shift;

    my $file = file(qw( schema Silki.sql ));

    my ($version_insert)
        = grep {/INSERT INTO "Version"/}
        read_file( $file->resolve()->stringify() );

    my ($next_version) = $version_insert =~ /VALUES \((\d+)\)/;

    die "Cannot find a version in the current schema!"
        unless $next_version;

    return $next_version;
}

sub _drop_and_create_db {
    my $self = shift;

    my $name = $self->name();

    my $command = <<"EOF";
SET CLIENT_MIN_MESSAGES = ERROR;

DROP DATABASE IF EXISTS "$name";

CREATE DATABASE "$name"
       ENCODING 'UTF8';
EOF

    my $dir = tempdir( CLEANUP => 1 );
    my $file = file( $dir, 'recreate-db.sql' );

    open my $fh, '>', $file;
    print {$fh} $command;
    close $fh;

    $self->_msg(
        "Dropping (if necessary) and creating the Silki database (database name = $name)"
    );

    system(
        'psql', 'template1', $self->_psql_args(), '-q', '-f',
        $file
    );
}

sub _build_db {
    my $self = shift;

    my $schema_file = file( 'schema', 'Silki.sql' );

    $self->_msg("Creating schema from $schema_file");

    system(
        'psql', $self->name(), $self->_psql_args(), '-q', '-f',
        $schema_file
    ) and die 'Cannot create Silki database with psql';
}

sub _psql_args {
    my $self = shift;

    my @args;

    if ( $self->username() ) {
        push @args, '-U', $self->username();
    }

    if ( $self->password() ) {
        push @args, '-W', $self->password();
    }

    if ( $self->host() ) {
        push @args, '-h', $self->host();
    }

    if ( $self->port() ) {
        push @args, '-p', $self->port();
    }

    return @args;
}

sub _seed_data {
    my $self = shift;

    my %config = ( name => $self->name() );

    for my $key (qw( username password host port )) {
        $config{$key} = $self->$key()
            if defined $self->$key();
    }

    require Silki::Config;

    local Silki::Config->_config_hash()->{db} = \%config;

    require Silki::SeedData;

    my $name = $self->name();
    $self->_msg("Seeding the $name database");

    Silki::SeedData::seed_data( ! $self->quiet() );
}

sub _msg {
    my $self = shift;

    return if $self->quiet();

    my $msg = shift;

    print "  $msg\n\n";
}

1;

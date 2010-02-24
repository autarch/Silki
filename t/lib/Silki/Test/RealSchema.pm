package Silki::Test::RealSchema;

use strict;
use warnings;

use DBD::Pg;
use DBI;
use File::Slurp qw( read_file );
use Path::Class qw( file );

sub import {
    if ( _database_exists() ) {
        _clean_tables();
    }
    else {
        _recreate_database();
        _run_ddl();
    }

    require Silki::Config;

    Silki::Config->new()->dbi_config()->{dsn} = 'dbi:Pg:dbname=SilkiTest';

    _seed_data();
}

sub _database_exists {
    my $dbh = eval {
        DBI->connect(
            'dbi:Pg:dbname=SilkiTest',
            q{}, q{}, {
                RaiseError         => 1,
                PrintError         => 0,
                PrintWarn          => 1,
                ShowErrorStatement => 1,
            },
        );
    };

    return if $@ || ! $dbh;

    my ($version_insert) = grep { /INSERT INTO "Version"/ } _ddl_statements();

    my ($expect_version) = $version_insert =~ /VALUES \((\d+)\)/;

    my $col = eval { $dbh->selectcol_arrayref( q{SELECT version FROM "Version"} ) };

    return $col && defined $col->[0] && $col->[0] == $expect_version;
}

sub _recreate_database {
    my $dbh = DBI->connect(
        'dbi:Pg:dbname=template1',
        q{}, q{}, {
            RaiseError         => 1,
            PrintError         => 0,
            PrintWarn          => 1,
            ShowErrorStatement => 1,
        },
    );

    eval { $dbh->do(q{DROP DATABASE "SilkiTest"}) };
    $dbh->do(q{CREATE DATABASE "SilkiTest" ENCODING 'UTF8'});

    $dbh->disconnect();

    return 1;
}

sub _clean_tables {
    my $dbh = DBI->connect(
        'dbi:Pg:dbname=SilkiTest',
        q{}, q{}, {
            RaiseError         => 1,
            PrintError         => 0,
            PrintWarn          => 1,
            ShowErrorStatement => 1,
        },
    );

    my @tables;
    for my $stmt ( _ddl_statements() ) {
        next unless $stmt =~ /^CREATE TABLE (\S+)/;

        my $table = $1;
        next if $table eq q{"Version"};

        push @tables, $table;
    }

    while ( my $table = shift @tables ) {
        # This is a hack because foreign keys may not let us delete from table
        # A while table B has rows.
        #
        # XXX - If this goes wrong, it'll loop forever. Not sure how best to
        # detect a cycle.
        eval { $dbh->do( "DELETE FROM $table" ) };

        if ($@) {
            push @tables, $table;
        }
    }
}

sub _run_ddl {
    my $dbh = DBI->connect(
        'dbi:Pg:dbname=SilkiTest',
        q{}, q{}, {
            RaiseError         => 1,
            PrintError         => 0,
            PrintWarn          => 1,
            ShowErrorStatement => 1,
        },
    );

    $dbh->do('SET CLIENT_MIN_MESSAGES = ERROR');

    # We cannot simply split on two newlines or we end up splitting in the
    # middle of plpgsql functions.
    for my $stmt ( _ddl_statements() ) {
        $dbh->do($stmt);
    }

    $dbh->disconnect();
}

{
    my @DDL;

    sub _ddl_statements {
        return @DDL if @DDL;

        my $file = file(
            $INC{'Silki/Test/RealSchema.pm'},
            '..', '..', '..', '..', '..',
            'schema',
            'Silki.sql'
        );

        my $ddl = read_file( $file->resolve()->stringify() );

        for my $stmt ( split /\n\n+(?=^\S)/m, $ddl ) {
            $stmt =~ s/^--.+\n//gm;

            next unless $stmt =~ /^(?:CREATE|ALTER|INSERT)/;

            next if $stmt =~ /^CREATE DATABASE/;

            push @DDL, $stmt;
        }

        return @DDL;
    }
}

sub _seed_data {
    require Silki::SeedData;

    Silki::SeedData::seed_data();
}

1;

package Silki::Build;

use strict;
use warnings;

use File::Path qw( mkpath );
use File::Spec;

use base 'Module::Build';

sub new {
    my $class = shift;
    my %args  = @_;

    $args{get_options} = {
        'db-name'     => { type => '=s', default => 'Silki' },
        'db-username' => { type => '=s' },
        'db-password' => { type => '=s' },
        'db-host'     => { type => '=s' },
        'db-port'     => { type => '=s' },
    };

    my $self = $class->SUPER::new(%args);

    $self->_update_from_existing_config();

    return $self
}

sub _update_from_existing_config {
    my $self = shift;

    my $config = eval {
        local $ENV{SILKI_CONFIG}
            = $self->args('etc-dir')
            ? File::Spec->catfile( $self->args('etc-dir'), 'silki.conf' )
            : undef;

        require Silki::Config;

        Silki::Config->instance();
    };

    return unless $config;

    for my $pair (
        [ database_name     => 'db-name' ],
        [ database_username => 'db-username' ],
        [ database_password => 'db-password' ],
        [ database_host     => 'db-host' ],
        [ database_port     => 'db-port' ],
        [ share_dir         => 'share-dir' ],
        ) {

        my ( $config_key, $mb_key ) = @{$pair};
        my $value = $config->$config_key
            or next;

        $self->args( $mb_key => $value . q{} );
    }

    Silki::Config->_clear_instance();

    return;
}

sub process_share_dir_files {
    my $self = shift;

    return if $self->args('share-dir');

    return $self->SUPER::process_share_dir_files(@_);
}

sub ACTION_install {
    my $self = shift;

    $self->SUPER::ACTION_install(@_);

    $self->dispatch('share');

    $self->dispatch('database');

    $self->dispatch('config');
}

sub ACTION_share {
    my $self = shift;

    my $share_dir = $self->args('share-dir')
        or return;

    for my $file ( grep { -f } @{ $self->rscan_dir('share') } ) {
        ( my $shareless = $file ) =~ s{share[/\\]}{};

        $self->copy_if_modified(
            from => $file,
            to   => File::Spec->catfile( $share_dir, $shareless ),
        );
    }

    return;
}

sub ACTION_database {
    my $self = shift;

    require Silki::DBInstaller;

    my %db_config;

    my %args = $self->args();

    for my $key ( grep { defined $args{$_} } grep { /^db-/ } keys %args ) {
        ( my $no_prefix = $key ) =~ s/^db-//;
        $db_config{$no_prefix} = $args{$key};
    }

    Silki::DBInstaller->new(
        %db_config,
        production => 1,
        quiet      => $self->quiet(),
    )->update_or_install_db();
}

sub ACTION_config {
    my $self = shift;

    my $config_file = File::Spec->catfile( $self->args('etc-dir')
            || ( '', 'etc', 'silki' ), 'silki.conf' );

    require Silki::Config;

    my $config = Silki::Config->instance();

    $config->_set_config_file( Path::Class::file($config_file) );
    $config->_set_is_production(1);

    if ( -f $config_file ) {
        $self->log_info("  You already have a config file at $config_file.\n\n");
        return;
    }
    else {
        $self->log_info("  Generating a new config file at $config_file.\n\n");
    }

    my %args = $self->args();

    $config->_set_share_dir( $args{'share-dir'} )
        if $args{'share-dir'};

    $config->_set_cache_dir( $args{'cache-dir'} )
        if $args{'cache-dir'};

    for my $key ( grep { defined $args{$_} } grep { /^db-/ } keys %args ) {
        ( my $config_key = $key ) =~ s/^db-/database_/;

        my $set = '_set_' . $config_key;
        $config->$set( $args{$key} );
    }

    require Digest::SHA;
    my $secret = Digest::SHA::sha1_hex( time . $$ . rand( 1_000_000_000 ) );
    $config->_set_secret($secret);

    my @skip;
    push @skip, 'cache' unless $args{'cache-dir'};
    push @skip, 'share' unless $args{'share-dir'};

    $config->write_config_file( file => $config_file, skip => \@skip );
}

1;

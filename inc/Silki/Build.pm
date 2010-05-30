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

    my $self = $class->SUPER::new(
        %args,
        recursive_test_files => 1,
    );

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

        require Silki::ConfigFile;

        Silki::ConfigFile->new()->raw_data();
    };

    return unless $config;

    my %map = (
        database => {
            name     => 'db-name',
            username => 'db-username',
            password => 'db-password',
            host     => 'db-host',
            port     => 'db-port',
        },
        dirs => { share => 'share-dir' },
    );

    for my $section (keys %map ) {
        for my $key ( keys %{$map{$section}} ) {
            my $value = $config->{$section}{$key};

            next unless defined $value && $value ne q{};

            my $mb_key = $map{$section}{$key};
            $self->args( $mb_key => $value );
        }
    }

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

    if ( -f $config_file ) {
        $self->log_info("  You already have a config file at $config_file.\n\n");
        return;
    }
    else {
        $self->log_info("  Generating a new config file at $config_file.\n\n");
    }

    require Digest::SHA;
    my $secret = Digest::SHA::sha1_hex( time . $$ . rand(1_000_000_000) );

    my %values = (
        'Silki/is_production' => 1,
        'Silki/secret'        => $secret,
    );

    my %args = $self->args();

    $values{'dirs/share'} = $args{'share-dir'}
        if $args{'share-dir'};

    $values{'dirs/cache'} = $args{'cache-dir'}
        if $args{'cache-dir'};

    for my $key ( grep { defined $args{$_} } grep {/^db-/} keys %args ) {
        ( my $conf_key = $key ) =~ s/^db-//;
        $values{"database/$conf_key"} = $args{$key};
    }

    $config->write_config_file( file => $config_file, values => \%values );
}

1;

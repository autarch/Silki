package Silki::Build;

use strict;
use warnings;

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

    return $class->SUPER::new(%args);
}

sub ACTION_install {
    my $self = shift;

    $self->SUPER::ACTION_install(@_);

    $self->dispatch('database');

    $self->dispatch('config');
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

    Silki::DBInstaller->new(%db_config)->update_or_install_db();
}

sub ACTION_config {
    my $self = shift;

    require Silki::Config;

    
}

1;

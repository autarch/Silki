package Silki::Web::CombinedStaticFiles;

use strict;
use warnings;
use namespace::autoclean;

use autodie;
use DateTime;
use File::Copy qw( move );
use File::Slurp qw( read_file );
use File::Temp qw( tempfile );
use JavaScript::Squish;
use JSAN::ServerSide 0.04;
use List::AllUtils qw( all );
use Path::Class;
use Silki::Config;
use Silki::Util qw( string_is_empty );
use Time::HiRes;

use Moose::Role;

has files => (
    is      => 'ro',
    isa     => 'ArrayRef[Path::Class::File]',
    lazy    => 1,
    builder => '_build_files',
);

has target_file => (
    is      => 'ro',
    isa     => 'Path::Class::File',
    lazy    => 1,
    builder => '_build_target_file',
);

has header => (
    is      => 'ro',
    isa     => 'Str',
    builder => '_build_header',
);

requires qw( _squish );

sub _build_header {
    return q{};
}

sub create_single_file {
    my $self = shift;

    my $target = $self->target_file();

    my $target_mod = -f $target ? $target->stat()->mtime() : 0;

    return
        unless grep { $_->stat()->mtime() >= $target_mod }
            @{ $self->files() };

    my ( $fh, $tempfile ) = tempfile( UNLINK => 0 );

    my $now = DateTime->from_epoch(
        epoch     => time,
        time_zone => 'local',
    )->strftime('%Y-%m-%d %H:%M:%S.%{nanosecond} %{time_zone_long_name}');

    print {$fh} "/* Generated at $now */\n\n";

    my $header = $self->header();
    print {$fh} $header
        unless string_is_empty($header);

    for my $file ( @{ $self->files() } ) {
        print {$fh} "\n\n/* $file */\n\n";
        print {$fh} $self->_squish( $self->_process($file) );
    }

    close $fh;

    move( $tempfile => $target )
        or die "Cannot move $tempfile => $target: $!";
}

sub _process {
    my $self = shift;
    my $file = shift;

    return scalar read_file( $file->stringify() );
}

1;

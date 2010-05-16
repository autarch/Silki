package Silki::Web::CSS;

use strict;
use warnings;
use namespace::autoclean;

use autodie qw( :all );
use CSS::Minifier qw( minify );
use File::Slurp qw( read_file );
use File::Temp;
use File::Which qw( which );
use Path::Class;
use Silki::Config;
use Silki::Types qw( Str );

use Moose;

with 'Silki::Web::CombinedStaticFiles';

has lessc_path => (
    is      => 'ro',
    isa     => Str,
    builder => '_build_lessc_path',
);

sub _build_files {
    my $dir = dir( Silki::Config->new()->share_dir(), 'css-source' );

    return [
        sort
            grep {
                  !$_->is_dir()
                && $_->basename() =~ /^\d+/
                && $_->basename()
                =~ /\.(?:css|less)$/
            } $dir->children()
    ];
}

sub _build_target_file {
    my $css_dir = dir( Silki::Config->new()->var_lib_dir(), 'css' );

    $css_dir->mkpath( 0, 0755 );

    return file( $css_dir, 'silki-combined.css' );
}

sub _squish {
    my $self = shift;
    my $css  = shift;

    return minify( input => $css );
}

sub _process {
    my $self = shift;
    my $file = shift;

    my $filename = $file->stringify();

    # We need to delay unlinking of the temp file until after it is read.
    my $temp;
    if ( $filename =~ /\.less$/ ) {
        $temp = File::Temp->new();
        system( $self->lessc_path(), $filename, $temp->filename() );
        $filename = $temp->filename();
    }

    return scalar read_file($filename);

}

sub _build_lessc_path {
    my $self = shift;

    my $bin = which('lessc');
    returm $bin if $bin;

    my $default = '/var/lib/gems/1.8/bin/lessc';
    return $default if -f $default;

    die "Cannot find lessc in your path or at $default";
}

__PACKAGE__->meta()->make_immutable();

1;

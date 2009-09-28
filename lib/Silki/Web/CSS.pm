package Silki::Web::CSS;

use strict;
use warnings;

use CSS::Minifier qw( minify );
use Path::Class;
use Silki::Config;

use Moose;

extends 'Silki::Web::CombinedStaticFiles';

sub _files {
    my $dir = dir( Silki::Config->new()->share_dir(), 'css-source' );

    return [
        sort
            grep {
                  !$_->is_dir()
                && $_->basename() =~ /^\d+/
                && $_->basename()
                =~ /\.css$/
            } $dir->children()
    ];
}

sub _target_file {
    my $css_dir = dir( Silki::Config->new()->var_lib_dir(), 'css' );

    $css_dir->mkpath( 0, 0755 );

    return file( $css_dir, 'silki-combined.css' );
}

sub _squish {
    my $self = shift;
    my $css  = shift;

    return minify( input => $css );
}

no Moose;

__PACKAGE__->meta()->make_immutable();

1;

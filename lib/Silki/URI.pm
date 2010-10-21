package Silki::URI;

use strict;
use warnings;

use Exporter qw( import );

our @EXPORT_OK = qw( dynamic_uri static_uri );

use List::AllUtils qw( all );
use Silki::Config;
use Silki::Util qw( string_is_empty );
use URI::FromHash ();

sub dynamic_uri {
    my %p = @_;

    $p{path}
        = _prefixed_path( Silki::Config->new()->path_prefix(), $p{path} );

    return URI::FromHash::uri(%p);
}

sub static_uri {
    my $path = shift;

    return _prefixed_path(
        Silki::Config->new()->static_path_prefix(),
        $path
    );
}

sub _prefixed_path {
    my $prefix = shift;
    my $path   = shift;

    return '/'
        if all { string_is_empty($_) } $prefix, $path;

    $path = ( $prefix || '' ) . ( $path || '' );

    return $path;
}

1;

# ABSTRACT: A utility module for generating URIs

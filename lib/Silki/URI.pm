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
        = _prefixed_path( Silki::Config->instance()->path_prefix(), $p{path} );

    return URI::FromHash::uri(%p);
}

{
    my $StaticPathPrefix;

    my $config = Silki::Config->instance();
    if ( $config->is_production() ) {
        $StaticPathPrefix = $config->path_prefix();
        $StaticPathPrefix .= q{/};
        $StaticPathPrefix .= $Silki::Config::VERSION || 'wc';
    }
    else {
        $StaticPathPrefix = q{};
    }

    sub static_uri {
        my $path = shift;

        return _prefixed_path(
            $StaticPathPrefix,
            $path
        );
    }
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

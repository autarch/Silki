package Silki::Web::Javascript;

use strict;
use warnings;
use namespace::autoclean;

use JavaScript::Minifier::XS qw( minify );
use JSAN::ServerSide 0.04;
use Path::Class;
use Silki::Config;

use Moose;

with 'Silki::Role::Web::CombinedStaticFiles';

sub _build_header {
    return q[var JSAN = { "use": function () {} };] . "\n";
}

sub _build_files {
    my $dir = dir( Silki::Config->instance()->share_dir(), 'js-source' );

    # Works around an error that comes from JSAN::Parse::FileDeps
    # attempting to assign $_, which is somehow read-only.
    local $_;
    my $js = JSAN::ServerSide->new(
        js_dir => $dir->stringify(),

        # This is irrelevant, as we won't be
        # serving the individual files.
        uri_prefix => '/',
    );

    $js->add('Silki');

    return [ map { file($_) } $js->files() ];
}

sub _build_target_file {
    my $js_dir = dir( Silki::Config->instance()->var_lib_dir(), 'js' );

    $js_dir->mkpath( 0, 0755 );

    return file( $js_dir, 'silki-combined.js' );
}

{
    my @Exceptions = (
        qr/\@cc_on/,
        qr/\@if/,
        qr/\@end/,
    );

    sub _squish {
        my $self = shift;
        my $code = shift;

        return $code
            unless Silki::Config->instance()->is_production();

        return minify($code);
    }
}

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: Combines and minifies Javascript source files

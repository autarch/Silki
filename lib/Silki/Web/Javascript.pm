package Silki::Web::Javascript;

use strict;
use warnings;

use JavaScript::Minifier::XS qw( minify );
use JSAN::ServerSide 0.04;
use Path::Class;
use Silki::Config;

use Moose;

extends 'Silki::Web::CombinedStaticFiles';

has '+header' => (
    default => q[var JSAN = { "use": function () {} };] . "\n",
);

sub _files {
    my $dir = dir( Silki::Config->new()->share_dir(), 'js-source' );

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

sub _target_file {
    my $js_dir = dir( Silki::Config->new()->var_lib_dir(), 'js' );

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

no Moose;

__PACKAGE__->meta()->make_immutable();

1;

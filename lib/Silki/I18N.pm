package Silki::I18N;

use strict;
use warnings;

use base 'Exporter';

our @EXPORT = qw( loc );

use Data::Localize;
use Path::Class qw( file );
use Silki::Config;

{
    my $DL = Data::Localize->new( fallback_languages => ['en'] );
    $DL->add_localizer(
        class => '+Silki::Gettext',
        path  => file( Silki::Config->new()->share_dir, 'i18n', '*.po' ),
    );

    sub SetLanguage {
        shift;
        $DL->set_languages(@_);
    }

    sub Language {
        shift;
        ( $DL->languages )[0];
    }

    sub loc {
        $DL->localize(@_);
    }
}

1;

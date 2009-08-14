package Silki::I18N;

use strict;
use warnings;

use base 'Exporter';

our @EXPORT = qw( loc );

use Data::Localize;
use Path::Class qw( file );


{
    my $DL = Data::Localize->new();
    $DL->add_localizer( class => '+Silki::Gettext',
                        path  => file( Silki::Config->new()->share_dir, 'i18n', '*.po' ),
                      );

    sub SetLanguage
    {
        shift;
        $DL->set_languages(@_);
    }

    sub loc
    {
        $DL->localize(@_);
    }
}

1;

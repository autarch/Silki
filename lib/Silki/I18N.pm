package Silki::I18N;

use strict;
use warnings;

use base 'Exporter';

our @EXPORT = qw( loc );

use Data::Localize;
use Path::Class qw( file );
use Silki::Config;

my $Loc = Data::Localize->new();
$Loc->add_localizer
    ( class => 'Gettext',
      path  => file( Silki::Config->new()->share_dir, 'i18n', '*.po' ),
    );

sub SetLanguage
{
    $Loc->set_languages(@_);
}

sub loc
{
    $Loc->localize(@_);
}

1;

package Silki::Build;

use strict;
use warnings;

use base 'Module::Build';

my %Requires = (
    'Catalyst::Plugin::Session::Store::DBI' => '0.15',
    'Data::Localize'                        => '0.00013_03',
    'Fey::ORM'                              => '0.32',
    'MooseX::ClassAttribute'                => '0',
    'MooseX::StrictConstructor'             => '0',
);

my %BuildRequires = (
    'Test::Exception' => '0',
    'Test::More'      => '0.88',
);


sub new {
    my $class = shift;

    return $class->SUPER::new(
        license              => 'perl',
        module_name          => 'Silki',
        requires             => \%Requires,
        build_requires       => \%BuildRequires,
        script_files         => [ glob('bin/*.pl') ],
        recursive_test_files => 1,
        meta_merge           => {
            resources => {
                repository => 'http://hg.urth.org/hg/Silki',
            },
        },
    );
}

1;

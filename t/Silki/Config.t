use strict;
use warnings;

use Test::Most;

use autodie;
use Cwd qw( abs_path );
use File::Basename qw( dirname );
use File::HomeDir;
use File::Temp qw( tempdir );
use Path::Class qw( dir );
use Silki::Config;

my $dir = tempdir( CLEANUP => 1 );

{
    my $config = Silki::Config->instance();

    is_deeply(
        $config->_build_config_hash(),
        {},
        'config hash is empty by default'
    );

    {
        local $ENV{SILKI_CONFIG} = '/path/to/nonexistent/file.conf';

        throws_ok(
            sub { $config->_build_config_hash() },
            qr/\QNonexistent config file in SILKI_CONFIG env var/,
            'SILKI_CONFIG pointing to bad file throws an error'
        );
    }

    my $dir = tempdir( CLEANUP => 1 );
    my $file = "$dir/silki.conf";
    open my $fh, '>', $file;
    print {$fh} <<'EOF';
[Silki]
secret = foobar
EOF
    close $fh;

    {
        local $ENV{SILKI_CONFIG} = $file;

        is_deeply(
            $config->_build_config_hash(), {
                Silki => { secret => 'foobar' },
            },
            'config hash uses data from file in SILKI_CONFIG'
        );
    }

    open $fh, '>', $file;
    print {$fh} <<'EOF';
[Silki]
is_production = 1
EOF
    close $fh;

    {
        local $ENV{SILKI_CONFIG} = $file;

        throws_ok(
            sub { $config->_build_config_hash() },
            qr/\QYou must supply a value for [Silki] - secret when running Silki in production/,
            'If is_production is true in config, there must be a secret defined'
        );
    }


    open $fh, '>', $file;
    print {$fh} <<'EOF';
[Silki]
is_production = 1
secret = foobar
EOF
    close $fh;

    {
        local $ENV{SILKI_CONFIG} = $file;

        is_deeply(
            $config->_build_config_hash(), {
                Silki => {
                    secret        => 'foobar',
                    is_production => 1,
                },
            },
            'config hash with is_production true and a secret defined'
        );
    }
}

Silki::Config->_clear_instance();

{
    my $config = Silki::Config->instance();

    my @base_imports = qw(
        AuthenCookie
        +Silki::Plugin::ErrorHandling
        Session::AsObject
        Session::State::URI
        +Silki::Plugin::Session::Store::Silki
        RedirectAndDetach
        SubRequest
        Unicode
    );

    is_deeply(
        $config->_build_catalyst_imports(),
        [ @base_imports, 'Static::Simple', 'StackTrace' ],
        'catalyst imports by default in dev setting'
    );

    $config->_set_is_production(1);

    is_deeply(
        $config->_build_catalyst_imports(),
        [ @base_imports ],
        'catalyst imports by default in production setting'
    );

    $config->_set_is_production(0);

    $config->_set_is_profiling(1);

    is_deeply(
        $config->_build_catalyst_imports(),
        [ @base_imports ],
        'catalyst imports by default in profiling setting'
    );

    $config->_set_is_profiling(0);

    {
        local $ENV{MOD_PERL} = 1;

        is_deeply(
            $config->_build_catalyst_imports(),
            [ @base_imports, 'StackTrace' ],
            'catalyst imports by default under mod_perl'
        );
    }
}

Silki::Config->_clear_instance();

{
    my $config = Silki::Config->instance();

    my @roles = qw(
        Silki::AppRole::Domain
        Silki::AppRole::RedirectWithError
        Silki::AppRole::Tabs
        Silki::AppRole::User
    );

    is_deeply(
        $config->_build_catalyst_roles(),
        \@roles,
        'catalyst roles'
    );
}

Silki::Config->_clear_instance();

{
    my $config = Silki::Config->instance();

    is(
        $config->_build_is_profiling(), 0,
        'is_profiling defaults to false'
    );

    local $INC{'Devel/NYTProf.pm'} = 1;

    is(
        $config->_build_is_profiling(), 1,
        'is_profiling defaults is true if Devel::NYTProf is loaded'
    );
}

Silki::Config->_clear_instance();

{
    my $config = Silki::Config->instance();

    my $home_dir = dir( File::HomeDir->my_home() );

    is(
        $config->_build_var_lib_dir(),
        $home_dir->subdir( '.silki', 'var', 'lib' ),
        'var lib dir defaults to $HOME/.silki/var/lib'
    );

    is(
        $config->_build_share_dir(),
        dir( dirname( abs_path($0) ), '..', '..', 'share' )->resolve(),
        'share dir defaults to $CHECKOUT/share'
    );

    is(
        $config->_build_etc_dir(),
        $home_dir->subdir( '.silki', 'etc' ),
        'etc dir defaults to $HOME/.silki/etc'
    );

    is(
        $config->_build_cache_dir(),
        $home_dir->subdir( '.silki', 'cache' ),
        'cache dir defaults to $HOME/.silki/cache'
    );

    is(
        $config->_build_files_dir(),
        $home_dir->subdir( '.silki', 'cache', 'files' ),
        'files dir defaults to $HOME/.silki/cache/files'
    );

    is(
        $config->_build_thumbnails_dir(),
        $home_dir->subdir( '.silki', 'cache', 'thumbnails' ),
        'thumbnails dir defaults to $HOME/.silki/cache/thumbnails'
    );
}

Silki::Config->_clear_instance();

{
    my $config = Silki::Config->instance();

    $config->_set_is_production(1);

    no warnings 'redefine';
    local *Silki::Config::_ensure_dir = sub {return};

    is(
        $config->_build_var_lib_dir(),
        '/var/lib/silki',
        'var lib dir defaults to /var/lib/silki in production'
    );

    is(
        $config->_build_share_dir(),
        '/usr/local/share/silki',
        'share dir defaults to /usr/local/share/silki in production'
    );

    is(
        $config->_build_etc_dir(),
        '/etc/silki',
        'etc dir defaults to /etc/silki in production'
    );

    is(
        $config->_build_cache_dir(),
        '/var/cache/silki',
        'cache dir defaults to /var/cache/silki in production'
    );

    is(
        $config->_build_files_dir(),
        '/var/cache/silki/files',
        'files dir defaults to /var/cache/silki/files in production'
    );

    is(
        $config->_build_thumbnails_dir(),
        '/var/cache/silki/thumbnails',
        'thumbnails dir defaults to /var/cache/silki/thumbnails in production'
    );
}

Silki::Config->_clear_instance();

{
    my $dir = tempdir( CLEANUP => 1 );
    my $file = "$dir/silki.conf";
    open my $fh, '>', $file;
    print {$fh} <<'EOF';
[dirs]
var_lib = /foo/var/lib
share   = /foo/share
etc     = /foo/etc
cache   = /foo/cache
EOF
    close $fh;

    no warnings 'redefine';
    local *Silki::Config::_ensure_dir = sub {return};

    {
        local $ENV{SILKI_CONFIG} = $file;

        my $config = Silki::Config->instance();

        is(
            $config->_build_var_lib_dir(),
            dir('/foo/var/lib'),
            'var lib dir defaults gets /foo/var/lib from file'
        );

        is(
            $config->_build_share_dir(),
            dir('/foo/share'),
            'var lib dir defaults gets /foo/share from file'
        );

        is(
            $config->_build_etc_dir(),
            dir('/foo/etc'),
            'var lib dir defaults gets /foo/etc from file'
        );

        is(
            $config->_build_cache_dir(),
            dir('/foo/cache'),
            'var lib dir defaults gets /foo/cache from file'
        );
    }
}

Silki::Config->_clear_instance();

{
    my $config = Silki::Config->instance();

    my $cat = $config->_build_catalyst_config();

    is(
        $cat->{default_view}, 'Mason',
        'Catalyst config - default_view = Mason',
    );

    is_deeply(
        $cat->{'Plugin::Session'}, {
            expires          => 300,
            dbi_table        => q{"Session"},
            dbi_dbh          => 'Silki::Plugin::Session::Store::Silki',
            object_class     => 'Silki::Web::Session',
            rewrite_body     => 0,
            rewrite_redirect => 1,
        },
        'Catalyst config - Plugin::Session'
    );

    is_deeply(
        $cat->{authen_cookie}, {
            name       => 'Silki-user',
            path       => '/',
            mac_secret => $config->secret(),
        },
        'Catalyst config - authen_cookie'
    );

    is(
        $cat->{root}, $config->share_dir(),
        'Catalyst config - root is share_dir',
    );

    is_deeply(
        $cat->{static}, {
            dirs         => [qw( files images js css static w3c ckeditor )],
            include_path => [
                $config->cache_dir()->stringify(),
                $config->var_lib_dir()->stringify(),
                $config->share_dir()->stringify(),
            ],
            debug => 1,
        },
        'Catalyst config - static in dev environment'
    );

    $config->_set_is_production(1);

    $cat = $config->_build_catalyst_config();

    ok( !$cat->{static}, 'no static config for prod environment' );
}

Silki::Config->_clear_instance();

{
    my $config = Silki::Config->instance();

    is_deeply(
        $config->_build_dbi_config(), {
            dsn      => 'dbi:Pg:dbname=Silki',
            username => q{},
            password => q{},
        },
        'default dbi config'
    );
}

Silki::Config->_clear_instance();

{
    my $dir = tempdir( CLEANUP => 1 );
    my $file = "$dir/silki.conf";
    open my $fh, '>', $file;
    print {$fh} <<'EOF';
[db]
name = Foo
host = example.com
port = 9876
username = user
password = pass
EOF
    close $fh;

    local $ENV{SILKI_CONFIG} = $file;

    my $config = Silki::Config->instance();

    is_deeply(
        $config->_build_dbi_config(), {
            dsn      => 'dbi:Pg:dbname=Foo;host=example.com;port=9876',
            username => 'user',
            password => 'pass',
        },
        'dbi config from file'
    );
}

Silki::Config->_clear_instance();

{
    my $config = Silki::Config->instance();

    my $home_dir = dir( File::HomeDir->my_home() );

    is_deeply(
        $config->_build_mason_config(), {
            comp_root =>
                dir( dirname( abs_path($0) ), '..', '..', 'share', 'mason' )
                ->resolve(),
            data_dir =>
                $home_dir->subdir( '.silki', 'cache', 'mason', 'web' ),
            error_mode           => 'fatal',
            in_package           => 'Silki::Mason::Web',
            use_match            => 0,
            default_escape_flags => 'h',
        },
        'default mason config'
    );
}

Silki::Config->_clear_instance();

{
    my $config = Silki::Config->instance();

    no warnings 'redefine';
    local *Silki::Config::_ensure_dir = sub {return};

    $config->_set_is_production(1);

    is_deeply(
        $config->_build_mason_config(), {
            comp_root                => '/usr/local/share/silki/mason',
            data_dir                 => '/var/cache/silki/mason/web',
            error_mode               => 'fatal',
            in_package               => 'Silki::Mason::Web',
            use_match                => 0,
            default_escape_flags     => 'h',
            static_source            => 1,
            static_source_touch_file => '/etc/silki/mason-touch',
        },
        'mason config in production'
    );
}

Silki::Config->_clear_instance();

{
    my $config = Silki::Config->instance();

    my $home_dir = dir( File::HomeDir->my_home() );

    is_deeply(
        $config->_build_mason_config_for_email(), {
            comp_root => dir(
                dirname( abs_path($0) ), '..', '..', 'share',
                'email-templates'
                )->resolve(),
            data_dir =>
                $home_dir->subdir( '.silki', 'cache', 'mason', 'email' ),
            error_mode           => 'fatal',
            in_package           => 'Silki::Mason::Email',
        },
        'default mason config for email'
    );
}

Silki::Config->_clear_instance();

{
    my $config = Silki::Config->instance();

    no warnings 'redefine';
    local *Silki::Config::_ensure_dir = sub {return};

    $config->_set_is_production(1);

    is_deeply(
        $config->_build_mason_config_for_email(), {
            comp_root            => '/usr/local/share/silki/email-templates',
            data_dir             => '/var/cache/silki/mason/email',
            error_mode           => 'fatal',
            in_package           => 'Silki::Mason::Email',
            static_source        => 1,
            static_source_touch_file => '/etc/silki/mason-touch',
        },
        'mason config for email in production'
    );
}

Silki::Config->_clear_instance();

{
    my $config = Silki::Config->instance();

    is(
        $config->static_path_prefix(), q{},
        'in dev environment, no static path prefix'
    );
}

Silki::Config->_clear_instance();

{
    my $dir = tempdir( CLEANUP => 1 );
    my $etc_dir = tempdir( CLEANUP => 1 );

    my $file = "$dir/silki.conf";
    open my $fh, '>', $file;
    print {$fh} <<"EOF";
[dirs]
etc = $etc_dir
EOF
    close $fh;

    my $rev_file = "$etc_dir/revision";
    open $fh, '>', $rev_file;
    print {$fh} '42';
    close $fh;

    local $ENV{SILKI_CONFIG} = $file;

    my $config = Silki::Config->instance();

    $config->_set_is_production(1);

    is(
        $config->static_path_prefix(), q{/42},
        'in prod environment, static path prefix includes revision number'
    );
}

Silki::Config->_clear_instance();

{
    my $dir = tempdir( CLEANUP => 1 );
    my $etc_dir = tempdir( CLEANUP => 1 );

    my $file = "$dir/silki.conf";
    open my $fh, '>', $file;
    print {$fh} <<"EOF";
[dirs]
etc = $etc_dir
EOF
    close $fh;

    my $rev_file = "$etc_dir/revision";
    open $fh, '>', $rev_file;
    print {$fh} '47';
    close $fh;

    local $ENV{SILKI_CONFIG} = $file;

    my $config = Silki::Config->instance();

    $config->_set_is_production(1);

    $config->_set_path_prefix('/foo');

    is(
        $config->static_path_prefix(), q{/foo/47},
        'in prod environment, static path prefix includes revision number and general prefix'
    );
}

done_testing();

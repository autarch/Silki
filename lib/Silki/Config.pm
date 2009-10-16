package Silki::Config;

use strict;
use warnings;

use Config::INI::Reader;
use File::HomeDir;
use Net::Interface;
use Path::Class;
use Silki::Types qw( Bool Str Int ArrayRef HashRef );
use Silki::Util qw( string_is_empty );
use Socket qw( AF_INET );
use Sys::Hostname qw( hostname );

use MooseX::Singleton;

has is_production => (
    is      => 'rw',
    isa     => Bool,
    lazy    => 1,
    default => sub { $_[0]->_config_hash()->{Silki}{is_production} },

    # for testing
    writer => '_set_is_production',
);

has is_test => (
    is      => 'rw',
    isa     => Bool,
    lazy    => 1,
    default => sub { $_[0]->_config_hash()->{Silki}{is_test} },

    # for testing
    writer => '_set_is_test',
);

has max_upload_size => (
    is      => 'ro',
    isa     => Int,
    lazy    => 1,
    default => sub {
        exists $_[0]->_config_hash()->{Silki}{max_upload_size}
            ? $_[0]->_config_hash()->{Silki}{max_upload_size}
            : ( 10 * 1024 * 1024 );
    },
);

has is_profiling => (
    is      => 'rw',
    isa     => Bool,
    lazy    => 1,
    builder => '_build_is_profiling',

    # for testing
    writer => '_set_is_profiling',
);

has _config_hash => (
    is      => 'rw',
    isa     => HashRef,
    lazy    => 1,
    builder => '_build_config_hash',

    # for testing
    writer  => '_set_config_hash',
    clearer => '_clear_config_hash',
);

has catalyst_imports => (
    is      => 'ro',
    isa     => ArrayRef[Str],
    lazy    => 1,
    builder => '_build_catalyst_imports',
);

has catalyst_roles => (
    is      => 'ro',
    isa     => ArrayRef[Str],
    lazy    => 1,
    builder => '_build_catalyst_roles',
);

has catalyst_config => (
    is      => 'ro',
    isa     => HashRef,
    lazy    => 1,
    builder => '_build_catalyst_config',
);

has dbi_config => (
    is      => 'ro',
    isa     => HashRef,
    lazy    => 1,
    builder => '_build_dbi_config',
);

has mason_config => (
    is      => 'ro',
    isa     => HashRef,
    lazy    => 1,
    builder => '_build_mason_config',
);

has _home_dir => (
    is      => 'ro',
    isa     => 'Path::Class::Dir',
    lazy    => 1,
    default => sub { dir( File::HomeDir->my_home() ) },
    writer  => '_set_home_dir',
);

has var_lib_dir => (
    is      => 'ro',
    isa     => 'Path::Class::Dir',
    lazy    => 1,
    builder => '_build_var_lib_dir',
);

has share_dir => (
    is      => 'ro',
    isa     => 'Path::Class::Dir',
    lazy    => 1,
    builder => '_build_share_dir',
);

has etc_dir => (
    is      => 'ro',
    isa     => 'Path::Class::Dir',
    lazy    => 1,
    builder => '_build_etc_dir',
);

has cache_dir => (
    is      => 'ro',
    isa     => 'Path::Class::Dir',
    lazy    => 1,
    builder => '_build_cache_dir',
);

has files_dir => (
    is      => 'ro',
    isa     => 'Path::Class::Dir',
    lazy    => 1,
    builder => '_build_files_dir',
);

has thumbnails_dir => (
    is      => 'ro',
    isa     => 'Path::Class::Dir',
    lazy    => 1,
    builder => '_build_thumbnails_dir',
);

has static_path_prefix => (
    is      => 'rw',
    isa     => Str,
    lazy    => 1,
    builder => '_build_static_path_prefix',

    # for testing
    writer  => '_set_static_path_prefix',
    clearer => '_clear_static_path_prefix',
);

has path_prefix => (
    is      => 'rw',
    isa     => Str,
    default => sub { $_[0]->_config_hash()->{Silki}{path_prefix} || q{} },

    # for testing
    writer => '_set_path_prefix',
);

has system_hostname => (
    is      => 'ro',
    isa     => Str,
    lazy    => 1,
    builder => '_build_system_hostname',
);

has secret => (
    is      => 'ro',
    isa     => Str,
    lazy    => 1,
    builder => '_build_secret',

    # for testing
    writer => '_set_secret',
);

sub _build_config_hash {
    my $self = shift;

    my $file = $self->_find_config_file()
        or return {};

    my $hash = Config::INI::Reader->read_file($file);

    # Can't call $self->is_production() or else we get a loop
    if ( $hash->{Silki}{is_production} ) {
        die
            'You must supply a value for [Silki] - secret when running Silki in production'
            if string_is_empty( $hash->{Silki}{secret} );
    }

    return $hash;
}

sub _find_config_file {
    my $self = shift;

    if ( !string_is_empty( $ENV{SILKI_CONFIG} ) ) {
        die
            "Nonexistent config file in SILKI_CONFIG env var: $ENV{SILKI_CONFIG}"
            unless -f $ENV{SILKI_CONFIG};

        return file( $ENV{SILKI_CONFIG} );
    }

    my @dirs = dir('/etc/silki');
    push @dirs, $self->_home_dir()->subdir( '.silki', 'etc' )
        if $>;

    for my $dir (@dirs) {
        my $file = $dir->file('silki.conf');

        return $file if -f $file;
    }

    return;
}

{
    my @StandardImports = qw(
        AuthenCookie
        +Silki::Plugin::ErrorHandling
        Session::AsObject
        Session::State::URI
        +Silki::Plugin::Session::Store::Silki
        RedirectAndDetach
        SubRequest
        Unicode
    );

    sub _build_catalyst_imports {
        my $self = shift;

        my @imports = @StandardImports;
        push @imports, 'Static::Simple'
            unless $ENV{MOD_PERL} || $self->is_profiling();

        push @imports, 'StackTrace'
            unless $self->is_production() || $self->is_profiling();

        return \@imports;
    }
}

{
    my @StandardRoles = qw(
        Silki::AppRole::Domain
        Silki::AppRole::RedirectWithError
        Silki::AppRole::Tabs
        Silki::AppRole::User
    );

    sub _build_catalyst_roles {
        return \@StandardRoles;
    }
}

{
    my @Profilers = qw(
        Devel/DProf.pm
        Devel/FastProf.pm
        Devel/NYTProf.pm
        Devel/Profile.pm
        Devel/Profiler.pm
        Devel/SmallProf.pm
    );

    sub _build_is_profiling {
        return 1 if grep { $INC{$_} } @Profilers;
        return 0;
    }
}

sub _build_var_lib_dir {
    my $self = shift;

    return $self->_dir(
        [ 'var', 'lib' ],
        '/var/lib/silki',
    );
}

sub _build_share_dir {
    my $self = shift;

    return $self->_dir(
        ['share'],
        '/usr/local/share/silki',
        dir('share')->absolute(),
    );
}

sub _build_etc_dir {
    my $self = shift;

    return $self->_dir(
        ['etc'],
        '/etc/silki',
    );
}

sub _build_cache_dir {
    my $self = shift;

    return $self->_dir(
        ['cache'],
        '/var/cache/silki',
    );
}

sub _build_files_dir {
    my $self = shift;

    my $cache = $self->cache_dir();

    my $files_dir = $cache->subdir('files');

    $self->_ensure_dir($files_dir);

    return $files_dir;
}

sub _build_thumbnails_dir {
    my $self = shift;

    my $cache = $self->cache_dir();

    my $thumbnails_dir = $cache->subdir('thumbnails');

    $self->_ensure_dir($thumbnails_dir);

    return $thumbnails_dir;
}

sub _dir {
    my $self = shift;

    my $dir = $self->_pick_dir(@_);

    $self->_ensure_dir($dir);

    return $dir;
}

sub _pick_dir {
    my $self         = shift;
    my $pieces       = shift;
    my $prod_default = shift;
    my $dev_default  = shift;

    my $config = $self->_config_hash();

    my $key = join '_', @{$pieces};

    return dir( $config->{dirs}{$key} )
        if exists $config->{dirs}{$key};

    return dir($prod_default)
        if $self->is_production();

    return $dev_default
        if defined $dev_default;

    return dir( $self->_home_dir(), '.silki', @{$pieces} );
}

sub _ensure_dir {
    my $self = shift;
    my $dir  = shift;

    return if -d $dir;

    $dir->mkpath( 0, 0755 )
        or die "Cannot make $dir: $!";

    return;
}

sub _build_catalyst_config {
    my $self = shift;

    my %config = (
        default_view => 'Mason',

        'Plugin::Session' => {
            expires => ( 60 * 5 ),

            # Need to quote it for Pg
            dbi_table        => q{"Session"},
            dbi_dbh          => 'Silki::Plugin::Session::Store::Silki',
            object_class     => 'Silki::Web::Session',
            rewrite_body     => 0,
            rewrite_redirect => 1,
        },

        authen_cookie => {
            name       => 'Silki-user',
            path       => '/',
            mac_secret => $self->secret(),
        },

        'Log::Dispatch' => $self->_log_config(),
    );

    $config{root} = $self->share_dir();

    unless ( $self->is_production() ) {
        $config{static} = {
            dirs         => [qw( files images js css static w3c ckeditor )],
            include_path => [
                __PACKAGE__->cache_dir()->stringify(),
                __PACKAGE__->var_lib_dir()->stringify(),
                __PACKAGE__->share_dir()->stringify(),
            ],
            debug => 1,
        };
    }

    return \%config;
}

{

    sub _log_config {
        my $self = shift;

        my @loggers;
        if ( $self->is_production() ) {
            if ( $ENV{MOD_PERL} ) {
                require Apache2::ServerUtil;

                push @loggers, {
                    class     => 'ApacheLog',
                    name      => 'ApacheLog',
                    min_level => 'warning',
                    apache    => Apache2::ServerUtil->server(),
                    callbacks => sub {
                        my %m = @_;
                        return 'silki: ' . $m{message};
                    },
                };
            }
            else {
                require Log::Dispatch::Syslog;

                push @loggers,
                    {
                    class     => 'Syslog',
                    name      => 'Syslog',
                    min_level => 'warning',
                    };
            }
        }
        else {
            push @loggers,
                {
                class     => 'Screen',
                name      => 'Screen',
                min_level => 'debug',
                };
        }

        return \@loggers;
    }
}

sub _build_dbi_config {
    my $self = shift;

    my $db_config = $self->_config_hash()->{db};

    my $dsn = 'dbi:Pg:dbname=' . ( $db_config->{name} || 'Silki' );

    $dsn .= ';host=' . $db_config->{host}
        if $db_config->{host};

    $dsn .= ';port=' . $db_config->{port}
        if $db_config->{port};

    return {
        dsn      => $dsn,
        username => ( $db_config->{username} || q{} ),
        password => ( $db_config->{password} || q{} ),
    };
}

sub _build_mason_config {
    my $self = shift;

    my %config = (
        comp_root => $self->share_dir()->subdir('mason')->stringify(),
        data_dir => $self->cache_dir()->subdir( 'mason', 'web' )->stringify(),
        error_mode           => 'fatal',
        in_package           => 'Silki::Mason',
        use_match            => 0,
        default_escape_flags => 'h',
    );

    if ( $self->is_production() ) {
        $config{static_source} = 1;
        $config{static_source_touch_file}
            = $self->etc_dir()->file('mason-touch')->stringify();
    }

    return \%config;
}

sub _build_static_path_prefix {
    my $self = shift;

    return $self->path_prefix() unless $self->is_production();

    my $prefix
        = string_is_empty( $self->path_prefix() )
        ? q{}
        : $self->path_prefix();

    return $prefix . q{/}
        . read_file( $self->etc_dir()->file('revision')->stringify() );
}

sub _build_system_hostname {
    for my $name (
        hostname(),
        map { scalar gethostbyaddr( $_->address(), AF_INET ) }
        grep { $_->address() } Net::Interface->interfaces()
        ) {
        return $name if $name =~ /\.[^.]+$/;
    }

    die 'Cannot determine system hostname.';
}

sub _build_secret {
    my $self = shift;

    return 'a big secret' unless $self->is_production();

    return $self->_config_hash()->{Silki}{secret};
}

__PACKAGE__->meta()->make_immutable();

no Moose;

1;

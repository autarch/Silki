package Silki::Config;

use strict;
use warnings;
use namespace::autoclean;

use Config::INI::Reader;
use File::HomeDir;
use File::Slurp qw( read_file );
use File::Temp qw( tempdir );
use Net::Interface;
use Path::Class;
use Silki::Types qw( Bool Str Int ArrayRef HashRef );
use Silki::Util qw( string_is_empty );
use Socket qw( AF_INET );
use Sys::Hostname qw( hostname );

use MooseX::MetaDescription;
use MooseX::Singleton;

has is_production => (
    traits  => ['MooseX::MetaDescription::Meta::Trait'],
    is      => 'rw',
    isa     => Bool,
    lazy    => 1,
    default => sub { $_[0]->_from_config_path('is_production') || 0 },

    # for testing
    writer      => '_set_is_production',
    description => {
        config_path => [ 'Silki', 'is_production' ],
        description =>
            'A flag indicating whether or not this is a production install. This should probably be true unless you are actively developing Silki.',
    },
);

has max_upload_size => (
    traits  => ['MooseX::MetaDescription::Meta::Trait'],
    is      => 'ro',
    isa     => Int,
    lazy    => 1,
    default => sub {
        $_[0]->_from_config_path('max_upload_size') || ( 10 * 1024 * 1024 );
    },
    description => {
        config_path => [ 'Silki', 'is_production' ],
        description =>
            'The maximum size of an upload in bytes. Defaults to 10 megabytes.',
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
    isa     => ArrayRef [Str],
    lazy    => 1,
    builder => '_build_catalyst_imports',
);

has serve_static_files => (
    traits      => ['MooseX::MetaDescription::Meta::Trait'],
    is          => 'ro',
    isa         => Bool,
    lazy        => 1,
    builder     => '_build_serve_static_files',
    description => {
        config_path => [ 'Silki', 'static' ],
        description =>
            'If this is true, the Silki application will serve static files itself. Defaults to false when is_production is true.',
    },
);

has catalyst_roles => (
    is      => 'ro',
    isa     => ArrayRef [Str],
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

has _db_name => (
    traits      => ['MooseX::MetaDescription::Meta::Trait'],
    is          => 'ro',
    isa         => Str,
    lazy        => 1,
    default     => sub { $_[0]->_from_config_path('_db_name') || 'Silki' },
    description => {
        config_path => [ 'db', 'name' ],
        description =>
            'The name of the database. Defaults to Silki.',
    },
);

has _db_username => (
    traits      => ['MooseX::MetaDescription::Meta::Trait'],
    is          => 'ro',
    isa         => Str,
    lazy        => 1,
    default     => sub { $_[0]->_from_config_path('_db_username') || q{} },
    description => {
        config_path => [ 'db', 'username' ],
        description =>
            'The username to use when connecting to the database. By default, this is empty.',
    },
);

has _db_password => (
    traits      => ['MooseX::MetaDescription::Meta::Trait'],
    is          => 'ro',
    isa         => Str,
    lazy        => 1,
    default     => sub { $_[0]->_from_config_path('_db_password') || q{} },
    description => {
        config_path => [ 'db', 'password' ],
        description =>
            'The password to use when connecting to the database. By default, this is empty.',
    },
);

has _db_host => (
    traits      => ['MooseX::MetaDescription::Meta::Trait'],
    is          => 'ro',
    isa         => Str,
    lazy        => 1,
    default     => sub { $_[0]->_from_config_path('_db_host') || q{} },
    description => {
        config_path => [ 'db', 'host' ],
        description =>
            'The host to use when connecting to the database. By default, this is empty.',
    },
);

has _db_port => (
    traits      => ['MooseX::MetaDescription::Meta::Trait'],
    is          => 'ro',
    isa         => Str,
    lazy        => 1,
    default     => sub { $_[0]->_from_config_path('_db_port') || q{} },
    description => {
        config_path => [ 'db', 'port' ],
        description =>
            'The port to use when connecting to the database. By default, this is empty.',
    },
);

has mason_config => (
    is      => 'ro',
    isa     => HashRef,
    lazy    => 1,
    builder => '_build_mason_config',
);

has mason_config_for_email => (
    is      => 'ro',
    isa     => HashRef,
    lazy    => 1,
    builder => '_build_mason_config_for_email',
);

has mason_config_for_help => (
    is      => 'ro',
    isa     => HashRef,
    lazy    => 1,
    builder => '_build_mason_config_for_help',
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
    traits      => ['MooseX::MetaDescription::Meta::Trait'],
    is          => 'ro',
    isa         => 'Path::Class::Dir',
    lazy        => 1,
    builder     => '_build_share_dir',
    description => {
        config_path => [ 'dirs', 'share' ],
        description =>
            'The directory where share files are located. By default, these are installed in the Perl module directory tree, but you might want to change this to something like /usr/local/share/Silki.',
    },
);

has etc_dir => (
    traits      => ['MooseX::MetaDescription::Meta::Trait'],
    is          => 'ro',
    isa         => 'Path::Class::Dir',
    lazy        => 1,
    builder     => '_build_etc_dir',
    description => {
        config_path => [ 'dirs', 'etc' ],
        description =>
            'The directory where config files are stored. Defaults to /etc/silki.',
    },
);

has cache_dir => (
    traits      => ['MooseX::MetaDescription::Meta::Trait'],
    is          => 'ro',
    isa         => 'Path::Class::Dir',
    lazy        => 1,
    builder     => '_build_cache_dir',
    description => {
        config_path => [ 'dirs', 'cache' ],
        description =>
            'The directory where generated files are stored. Defaults to /var/cache/silki.',
    },
);

has files_dir => (
    is      => 'ro',
    isa     => 'Path::Class::Dir',
    lazy    => 1,
    builder => '_build_files_dir',
);

has small_image_dir => (
    is      => 'ro',
    isa     => 'Path::Class::Dir',
    lazy    => 1,
    builder => '_build_small_image_dir',
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
    traits  => ['MooseX::MetaDescription::Meta::Trait'],
    is      => 'rw',
    isa     => Str,
    default => sub { $_[0]->_from_config_path('path_prefix') || q{} },

    # for testing
    writer      => '_set_path_prefix',
    description => {
        config_path => [ 'Silki', 'path_prefix' ],
        description =>
            'The URI path prefix for your Silki install. By default, this is empty. This affects URI generation and resolution.',
    },
);

has system_hostname => (
    is      => 'ro',
    isa     => Str,
    lazy    => 1,
    builder => '_build_system_hostname',
);

has antispam_key => (
    traits      => ['MooseX::MetaDescription::Meta::Trait'],
    is          => 'ro',
    isa         => Str,
    lazy        => 1,
    default     => sub { $_[0]->_from_config_path('antispam_key') || q{} },
    description => {
        config_path => [ 'antispam', 'key' ],
        description =>
            'A key for your antispam server. If this is empty, this Silki installation will not be able to check for spam links.',
    },
);

has antispam_server => (
    traits      => ['MooseX::MetaDescription::Meta::Trait'],
    is          => 'ro',
    isa         => Str,
    lazy        => 1,
    default     => sub { $_[0]->_from_config_path('antispam_server') || q{} },
    description => {
        config_path => [ 'antispam', 'key' ],
        description =>
            'The antispam server to use. This defaults to api.antispam.typepad.com.',
    },
);

has secret => (
    traits      => ['MooseX::MetaDescription::Meta::Trait'],
    is          => 'ro',
    isa         => Str,
    lazy        => 1,
    default     => sub { $_[0]->_from_config_path('secret') || q{} },
    description => {
        config_path => [ 'Silki', 'secret' ],
        description =>
            'A secret used as salt for digests in some URIs and for user authentication cookies. Changing this will invalidate all existing cookies.',
    },

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

sub _from_config_path {
    my $self      = shift;
    my $attr_name = shift;

    my $attr = $self->meta()->get_attribute($attr_name)
        or die "Bad attribute name: $attr_name";

    $attr->can('description')
        or die "Attribute $attr_name has no meta-description";

    my $path = $attr->description()->{config_path}
        or die
        "Attribute $attr_name has no config path in the meta-description";

    my $hash = $self->_config_hash();

    for my $key ( @{$path} ) {
        $hash = $hash->{$key}
            or return;
    }

    if ( ref $hash ) {
        die "Config path @{$path} did not resolve to a non-reference value";
    }

    return $hash;
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
            if $self->serve_static_files();

        push @imports, 'StackTrace'
            unless $self->is_production() || $self->is_profiling();

        return \@imports;
    }
}

sub _build_serve_static_files {
    my $self = shift;

    if ( exists $self->_config_hash()->{Silki}{static} ) {
        return $self->_config_hash()->{Silki}{static};
    }

    return !( $ENV{MOD_PERL}
        || $self->is_production()
        || $self->is_profiling() );
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

    # I'd like to use File::ShareDir, but it blows up if the directory doesn't
    # exist, which isn't very fucking helpful. This is equivalent to
    # dist_dir('Silki')
    my $share_dir = dir(
        dir( $INC{'Silki/Config.pm'} )->parent(),
        'auto', 'share', 'dist',
        'Silki'
    )->absolute()->cleanup();

    return $self->_dir(
        ['share'],
        $share_dir,
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

sub _build_small_image_dir {
    my $self = shift;

    my $cache = $self->cache_dir();

    my $small_image_dir = $cache->subdir('small-image');

    $self->_ensure_dir($small_image_dir);

    return $small_image_dir;
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

my $TestingRootDir;

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

    if ( $ENV{HARNESS_ACTIVE} ) {
        $TestingRootDir ||= tempdir( CLEANUP => 1 );

        return dir( $TestingRootDir, @{$pieces} );
    }

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
                $self->cache_dir()->stringify(),
                $self->var_lib_dir()->stringify(),
                $self->share_dir()->stringify(),
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

                push @loggers, {
                    class     => 'Syslog',
                    name      => 'Syslog',
                    min_level => 'warning',
                    };
            }
        }
        else {
            push @loggers, {
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

    my $dsn = 'dbi:Pg:dbname=' . $self->_db_name();

    if ( my $host = $self->_db_host() ) {
        $dsn .= ';host=' . $host;
    }

    if ( my $port = $self->_db_port() ) {
        $dsn .= ';port=' . $port;
    }

    return {
        dsn      => $dsn,
        username => ( $self->_db_username() || q{} ),
        password => ( $self->_db_password() || q{} ),
    };
}

sub _build_mason_config {
    my $self = shift;

    my %config = (
        comp_root => $self->share_dir()->subdir('mason')->stringify(),
        data_dir => $self->cache_dir()->subdir( 'mason', 'web' )->stringify(),
        error_mode           => 'fatal',
        in_package           => 'Silki::Mason::Web',
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

sub _build_mason_config_for_email {
    my $self = shift;

    my %config = (
        comp_root =>
            $self->share_dir()->subdir('email-templates')->stringify(),
        data_dir =>
            $self->cache_dir()->subdir( 'mason', 'email' )->stringify(),
        error_mode => 'fatal',
        in_package => 'Silki::Mason::Email',
    );

    if ( $self->is_production() ) {
        $config{static_source} = 1;
        $config{static_source_touch_file}
            = $self->etc_dir()->file('mason-touch')->stringify();
    }

    return \%config;
}

sub _build_mason_config_for_help {
    my $self = shift;

    my %config = (
        error_mode           => 'fatal',
        in_package           => 'Silki::Mason::Help',
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

sub _build_antispam_key {
    my $self = shift;

    return $self->_config_hash()->{Antispam}{key} || q{};
}

sub _build_antispam_server {
    my $self = shift;

    return $self->_config_hash()->{Antispam}{server} || q{};
}

sub _build_secret {
    my $self = shift;

    return 'a big secret' unless $self->is_production();

    return $self->_config_hash()->{Silki}{secret};
}

__PACKAGE__->meta()->make_immutable();

1;

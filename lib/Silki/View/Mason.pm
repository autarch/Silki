package Silki::View::Mason;

use strict;
use warnings;

use base 'Catalyst::View::Mason';

{
    package Silki::Mason::Web;

    use Data::Dumper;
    use HTML::Entities qw( encode_entities );
    use Lingua::EN::Inflect qw( A PL_N );
    use Number::Format qw( format_bytes );
    use Silki::I18N qw( loc );
    use Silki::Util qw( string_is_empty english_list );
    use Silki::URI qw( dynamic_uri static_uri );
    use URI::Escape qw( uri_escape );
}

# used in templates
use HTML::FillInForm;
use Markdent::Simple::Fragment;
use Path::Class;
use Silki::Config;
use Silki::Web::Form;
use Silki::Web::FormData;
use Silki::Util qw( string_is_empty );

{
    my $config = Silki::Config->new()->mason_config();
    $config->{escape_flags} = { nbsp => \&_nbsp_escape };

    __PACKAGE__->config($config);
}

sub _nbsp_escape {
    ${ $_[0] } =~ s/ /&nbsp;/g;

    return;
}

# sub new
# {
#     my $class = shift;

#     my $self = $class->SUPER::new(@_);

# #    Silki::Util::chown_files_for_server( $self->template()->files_written() );

#     return $self;
# }

sub has_template_for_path {
    my $self = shift;
    my $path = shift;

    return -f file(
        $self->config()->{comp_root},
        ( grep { !string_is_empty($_) } split /\//, $path ),
    );
}

1;

# ABSTRACT: A Mason-based view

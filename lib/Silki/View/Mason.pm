package Silki::View::Mason;

use strict;
use warnings;

use base 'Catalyst::View::Mason';

{

    package Silki::Mason;

    use Lingua::EN::Inflect qw( PL_N );
    use Silki::I18N qw( loc );
    use Silki::Util qw( string_is_empty english_list );
    use Silki::URI qw( static_uri );
}

# used in templates
use HTML::FillInForm;
use Path::Class;
use Silki::Config;
use Silki::Web::Form;
use Silki::Web::FormData;
use Silki::Util qw( string_is_empty );

__PACKAGE__->config( Silki::Config->new()->mason_config() );

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

__END__

=head1 NAME

Silki::View::Mason - Catalyst View

=head1 SYNOPSIS

See L<Silki>

=head1 DESCRIPTION

Catalyst View.

=head1 AUTHOR

Dave Rolsky,,,

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

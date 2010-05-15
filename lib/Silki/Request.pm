package Silki::Request;

use strict;
use warnings;

use Moose::Role;
use Silki::Util qw( string_is_empty );

sub user_params {
    my $self = shift;

    my $params = $self->params();

    my %p = $self->_params_for_classes('Silki::Schema::User');
    $p{password2} = $params->{password2}
        unless string_is_empty( $params->{password2} );

    return %p;
}

sub wiki_params {
    my $self = shift;

    return $self->_params_for_classes('Silki::Schema::Wiki');
}

sub domain_params {
    my $self = shift;

    return $self->_params_for_classes('Silki::Schema::Domain');
}

sub account_params {
    my $self = shift;

    return $self->_params_for_classes('Silki::Schema::Account');
}

sub _bool {
    return $_[0] ? 1 : 0;
}

sub _params_for_classes {
    my $self    = shift;
    my $classes = shift;
    my $suffix  = shift || '';

    my $params = $self->params();

    my %found;

    for my $class ( @{ ref $classes ? $classes : [$classes] } ) {
        my $table = $class->Table();

        my %pk = map { $_->name() => 1 } @{ $table->primary_key() };

        for my $col ( $table->columns() ) {
            my $name = $col->name();

            next if $pk{$name};

            my $key = $name;
            $key .= q{-} . $suffix
                if $suffix;

            if ( string_is_empty( $params->{$key} ) ) {
                if ( $col->is_nullable() ) {
                    $found{$name} = undef;
                }

                next;
            }

            $found{$name} = $params->{$key};
        }
    }

    return %found;
}

no Moose::Role;

1;


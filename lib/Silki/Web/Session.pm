package Silki::Web::Session;

use strict;
use warnings;

use Silki::Types qw( ArrayRef HashRef NonEmptyStr ErrorForSession );

use Moose;
use MooseX::AttributeHelpers;
use MooseX::Params::Validate qw( pos_validated_list );
use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;

has form_data => (
    is      => 'rw',
    isa     => 'HashRef',
    lazy    => 1,
    default => sub { {} },
);

has _errors => (
    metaclass => 'Collection::Array',
    is        => 'ro',
    isa       => ArrayRef [ NonEmptyStr | HashRef ],
    default   => sub { [] },
    init_arg  => undef,
    provides  => {
        push     => 'add_error',
        elements => 'errors',
    },
);

has _messages => (
    metaclass => 'Collection::Array',
    is        => 'ro',
    isa       => ArrayRef [NonEmptyStr],
    default   => sub { [] },
    init_arg  => undef,
    provides  => {
        push     => 'add_message',
        elements => 'messages',
    },
);

around add_error => sub {
    my $orig = shift;
    my $self = shift;

    return $self->$orig( map { $self->_error_text($_) } @_ );
};

sub _error_text {
    my $self = shift;
    my ($e) = pos_validated_list( \@_, { isa => ErrorForSession } );

    if ( eval { $e->can('messages') } && $e->messages() ) {
        return $e->messages();
    }
    elsif ( eval { $e->can('message') } ) {
        return $e->message();
    }
    elsif ( ref $e ) {
        return @{$e};
    }
    else {

        # force stringification
        return $e . q{};
    }
}

no Moose;

__PACKAGE__->meta()->make_immutable();

1;

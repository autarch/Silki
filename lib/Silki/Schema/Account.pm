package Silki::Schema::Account;

use strict;
use warnings;

use Silki::Schema;
use Silki::Schema::AccountAdmin;
use Silki::Types qw( Bool );

use Fey::ORM::Table;
use MooseX::Params::Validate qw( pos_validated_list );

has_policy 'Silki::Schema::Policy';

my $Schema = Silki::Schema->Schema();

has_table( $Schema->table('Account') );

sub add_admin
{
    my $self = shift;
    my ($user) = pos_validated_list( \@_, { isa => 'Silki::Schema::User' } );

    return if $user->is_system_user();

    Silki::Schema::AccountAdmin->insert( account_id => $self->account_id(),
                                         user_id    => $user->user_id(),
                                       );

    return;
}

no Fey::ORM::Table;

__PACKAGE__->meta()->make_immutable();


1;

__END__



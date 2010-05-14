package Silki::Schema::Account;

use strict;
use warnings;

use Silki::Schema;
use Silki::Schema::AccountAdmin;
use Silki::Types qw( Bool Int );

use Fey::ORM::Table;
use MooseX::ClassAttribute;
use MooseX::Params::Validate qw( pos_validated_list validated_list );

has_policy 'Silki::Schema::Policy';

my $Schema = Silki::Schema->Schema();

has_table( $Schema->table('Account') );

class_has _AllAccountSelect => (
    is      => 'ro',
    isa     => 'Fey::SQL::Select',
    lazy    => 1,
    builder => '_BuildAllAccountSelect',
);

sub add_admin {
    my $self = shift;
    my ($user) = pos_validated_list( \@_, { isa => 'Silki::Schema::User' } );

    return if $user->is_system_user();

    Silki::Schema::AccountAdmin->insert(
        account_id => $self->account_id(),
        user_id    => $user->user_id(),
    );

    return;
}

sub All {
    my $class = shift;
    my ( $limit, $offset ) = validated_list(
        \@_,
        limit  => { isa => Int, optional => 1 },
        offset => { isa => Int, default  => 0 },
    );

    my $select = $class->_AllAccountSelect()->clone();
    $select->limit( $limit, $offset );

    my $dbh = Silki::Schema->DBIManager()->source_for_sql($select)->dbh();

    return Fey::Object::Iterator::FromSelect->new(
        classes     => 'Silki::Schema::Account',
        select      => $select,
        dbh         => $dbh,
        bind_params => [ $select->bind_params() ],
    );
}

sub _BuildAllAccountSelect {
    my $class = shift;

    my $select = Silki::Schema->SQLFactoryClass()->new_select();

    my $account_t = $Schema->table('Account');

    $select->select($account_t)
           ->from($account_t)
           ->order_by( $account_t->column('name') );

    return $select;
}

no Fey::ORM::Table;

__PACKAGE__->meta()->make_immutable();

1;

__END__



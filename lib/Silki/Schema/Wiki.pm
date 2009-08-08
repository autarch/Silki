package Silki::Schema::Wiki;

use strict;
use warnings;

use Fey::Literal;
use Fey::Object::Iterator::FromSelect;
use Fey::SQL;
use Silki::Config;
use Silki::Schema;
use Silki::Schema::Domain;
use Silki::Schema::Page;
use Silki::Schema::Permission;
use Silki::Schema::Role;
use Silki::Schema::WikiRolePermission;
use Silki::Types qw( ValidPermissionType );

use Fey::ORM::Table;
use MooseX::Params::Validate qw( pos_validated_list );

with 'Silki::Role::Schema::URIMaker';

{
    my $schema = Silki::Schema->Schema();

    has_table( $schema->table('Wiki') );

    has_one( $schema->table('Domain') );

    has_many pages =>
        ( table    => $schema->table('Page'),
          order_by => [ $schema->table('Page')->column('title') ],
        );
}

my $FrontPage = <<'EOF';
Welcome to your new wiki.

A wiki is a set of web pages that can be read and edited by a group of people. You use simple to add things like *italics* and **bold** to the text. Wikis are designed to make linking to other pages easy.

For more information about wikis in general and Silki in particular, see the [[Help]] page.
EOF

my $Help = <<'EOF';
This need some content.
EOF

sub insert
{
    my $class = shift;
    my %p     = @_;

    my $wiki;

    $class->SchemaClass()->RunInTransaction
        ( sub
          {
              $wiki = $class->SUPER::insert(%p);

              Silki::Schema::Page->insert
                  ( title          => 'Front Page',
                    content        => $FrontPage,
                    wiki_id        => $wiki->wiki_id(),
                    user_id        => $wiki->user_id(),
                    can_be_renamed => 0,
                  );

              Silki::Schema::Page->insert
                  ( title          => 'Help',
                    content        => $Help,
                    wiki_id        => $wiki->wiki_id(),
                    user_id        => $wiki->user_id(),
                    can_be_renamed => 0,
                  );
          }
        );

    return $wiki;
}

sub _base_uri_path
{
    my $self = shift;

    return '/wiki/' . $self->short_name();
}

{
    my %Sets = ( 'public'           => { Anonymous => [ qw( Read Edit ) ],
                                         Member    => [ qw( Read Edit Archive Attachment ) ],
                                         Admin     => [ qw( Read Edit Archive Attachment Invite Manage ) ],
                                       },
                 'public-read-only' => { Anonymous => [ qw( Read ) ],
                                         Member    => [ qw( Read Edit Archive Attachment ) ],
                                         Admin     => [ qw( Read Edit Archive Attachment Invite Manage ) ],
                                       },
                 'private'          => { Anonymous => [],
                                         Member    => [ qw( Read Edit Archive Attachment Invite ) ],
                                         Admin     => [ qw( Read Edit Archive Attachment Invite Manage ) ],
                                       },
               );

    sub set_permissions
    {
        my $self   = shift;
        my ($type) = pos_validated_list( \@_, { isa => ValidPermissionType } );

        my $set = $Sets{$type};

        my @inserts;
        for my $role_name ( keys %{ $set } )
        {
            my $role = Silki::Schema::Role->$role_name();

            for my $perm_name ( @{ $set->{$role_name} } )
            {
                my $perm = Silki::Schema::Permission->$perm_name();

                push @inserts, { wiki_id       => $self->wiki_id(),
                                 role_id       => $role->role_id(),
                                 permission_id => $perm->permission_id(),
                               };
            }
        }

        Silki::Schema::WikiRolePermission->insert_many(@inserts);
    }
}

sub PublicWikiCount
{
    my $class = shift;

    my $select = Fey::SQL->new_select();

    my $distinct = Fey::Literal::Term->new( 'DISTINCT ', $class->Table()->column('wiki_id') );
    my $count = Fey::Literal::Function->new( 'COUNT', $distinct );
    $select->select($count);

    $class->_PublicWikiSelect($select);

    my $dbh = Silki::Schema->DBIManager()->source_for_sql($select)->dbh();

    my $vals = $dbh->selectrow_arrayref( $select->sql($dbh), {}, $select->bind_params() );

    return $vals ? $vals->[0] : 0;
}

sub PublicWikis
{
    my $class = shift;

    my $select = Fey::SQL->new_select();

    $select->select( $class->Table() );
    $class->_PublicWikiSelect($select);
    $select->order_by( $class->Table()->column('title') );
    $select->limit( 20, 0 );

    my $dbh = Silki::Schema->DBIManager()->source_for_sql($select)->dbh();

    return
        Fey::Object::Iterator::FromSelect->new
            ( classes     => 'Silki::Schema::Wiki',
              select      => $select,
              dbh         => $dbh,
              bind_params => [ $select->bind_params() ],
            );
}

sub _PublicWikiSelect
{
    my $class  = shift;
    my $select = shift;

    my $schema = Silki::Schema->Schema();

    my $anon = Silki::Schema::Role->Anonymous();
    my $read = Silki::Schema::Permission->Read();

    $select->from( $schema->tables( 'Wiki', 'WikiRolePermission' ) )
           ->where( $schema->table('WikiRolePermission')->column('role_id'),
                    '=', $anon->role_id() )
           ->and( $schema->table('WikiRolePermission')->column('permission_id'),
                  '=', $read->permission_id() );

    return;
}

no Fey::ORM::Table;
no Moose;

__PACKAGE__->meta()->make_immutable();


1;

__END__



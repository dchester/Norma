package Norma::ORM::Mappable;

use MooseX::Role::Parameterized;
use Norma::ORM::Meta::Display::Defaults;
use Norma::ORM::Collection;

parameter dbh              => ( required => 1 );
parameter table_name       => ( required => 1 );
parameter key_field_names  => ( isa => 'ArrayRef' );
parameter defaults         => ( isa => 'HashRef' );
parameter logger           => ( isa => 'CodeRef' );
parameter relationships    => ( isa => 'ArrayRef' );

role {
	my $p = shift;
	my $table_name = $p->table_name;

	die "invalid table_name: " . $p->table_name unless $p->table_name =~ /^\w+$/;

	my $columns_sth = $p->dbh->column_info(undef, undef, $table_name, '%');
	my $columns = $columns_sth->fetchall_arrayref({});

	my $primary_key_field_names = [ $p->dbh->primary_key(undef, undef, $table_name) ];
	my $key_field_names = [ grep {$_} map { $_ && @$_ } $primary_key_field_names, $p->key_field_names ];

	die "couldn't get table definition: $table_name" unless $columns;

	for my $column (@$columns) {

		$column->{_PRIMARY_KEY} = grep { $_ eq $column->{COLUMN_NAME} } @$primary_key_field_names ? 1 : 0;

		my $required = 
			$column->{NULLABLE} == 0 
			&& ! defined $column->{COLUMN_DEF}
			&& ! $column->{mysql_is_auto_increment};

		has $column->{COLUMN_NAME} => (
			is => 'rw',
			required => $required,
			traits => [qw(AttributeDisplayDefaults)],
		);
	}

	for my $relationship (@{ $p->relationships || [] }) {

		if ($relationship->{nature} eq 'belongs_to') {

			my $foreign_key = $relationship->{foreign_key} || "$relationship->{name}_id";
			my $foreign_primary_key = $relationship->{foreign_primary_key} || 'id';
			method "_build_$relationship->{name}" => sub { 
				my ($self) = @_;
				$relationship->{class}->new( 
					$foreign_primary_key => $self->$foreign_key
				);
			};

		} elsif ($relationship->{nature} eq 'has_many') {

			my $foreign_key = $relationship->{foreign_key} || $table_name . "_id";
			my $foreign_primary_key = $relationship->{foreign_primary_key} || 'id';
			my ($primary_key_name) = @{ $key_field_names };

			method "_build_$relationship->{name}" => sub { 
				my ($self) = @_;
				$relationship->{class}->collect( 
					where_clause => "$foreign_key = " . $self->$primary_key_name
				);
			};

		} else {
			method "_build_$relationship->{name}" => sub {};
		}
 
		has $relationship->{name} => (
			is => 'rw',
			lazy_build => 1,
		); 
	}

	method _table => sub {
		return {
			name => $p->table_name,
			columns => $columns,
			key_field_names => $key_field_names,
			dbh => $p->dbh
		};
	};

	method _defaults => sub { $p->defaults || {} };

	sub BUILDARGS {
		my $class = shift;
		use Data::Dumper;
		#print Dumper \@_;

		my %args = @_ > 1 ? @_ : @_ == 1 ? %{ shift @_ } : ();

		my $errors = $class->validate(%args);
		#die $errors if $errors;

		return \%args;
	}

	sub BUILD {
		my ($self, $args) = @_;
		#_fetch($self, %$args);
	}

	sub validate {
		my ($class, %args) = @_;
		
		my $errors;

		for my $attribute ($class->meta->get_all_attributes) {
			
			if ($attribute->has_type_constraint) {
				
				my $constraint = $attribute->type_constraint;
				my $value = $args{$attribute->name};

				unless ($constraint->check($args{$attribute->name})) {
					$errors->{$attribute->name} = $constraint->get_message($value);
				}
			}
			
			if ($attribute->is_required) {
				unless ($args{$attribute->name}) {
					$errors->{$attribute->name} = "Missing required value for " . $attribute->name;
				}
			}
		}
		return $errors;
	}

	sub _load_source {
		my ($class, %args) = @_;

		my $table = $class->_table;
		my $dbh = $table->{dbh};

		my $row;
		for my $field_name (@{ $table->{key_field_names} }) {

			if (defined $args{$field_name}) {
				my $query = "select * from $table->{name} where $field_name = ? limit 1";
				$row = $dbh->selectrow_hashref($query, undef, $args{$field_name}); 
				die "no row by that criteria: $class | $field_name => $args{$field_name}" unless $row;
				return {
					row => $row,
					key_field_name => $field_name,
					key_field_value => $args{$field_name}
				};	
			}
		}

		die "no unique criteria: $class | " . join ', ', %args;
	}

	sub reload {
		my ($self, %args) = @_;
		
		my $source = (ref $self)->_load_source(%args);
		
		for my $column_name (keys %{ $source->{row} }) {
			$self->$column_name( $source->{row}->{$column_name} );
		}
		$self->{_source} = $source;
	}
		
	sub load {
		my ($class, %args) = @_;

		my $table = $class->_table;
		my $dbh = $table->{dbh};
				
		my $source = $class->_load_source(%args);
		die "no source: %args" unless $source;

		my $object = $class->new(%{ $source->{row} });
		$object->{_source} = $source;

		return $object;
	}

	sub set {
		my ($self, %args) =  @_;
		
		for my $field_name (map { $_->{COLUMN_NAME} } @{ $self->_table->{columns} }) {
			next if grep { $_ eq $field_name } @{ $self->_table->{key_field_names} };
			next unless $args{$field_name};

			$self->$field_name($args{$field_name});
		} 
	}
	
	sub save {
		my ($self) = @_;
		my $table = $self->_table;
		my $dbh = $table->{dbh};
		my $source = $self->{_source};
		
		my @mutable_field_names = map { $_->{COLUMN_NAME} } grep { ! $_->{_PRIMARY_KEY} } @{ $table->{columns} };

		my @values_clauses;
		for my $field_name (@mutable_field_names) {
			my $quoted_value;
			if ($self->$field_name && $self->$field_name =~ m|^sql:(.+)|) {
				my $sql_expression = $1;
				if ($sql_expression eq 'now()') {
					$quoted_value = $sql_expression;
				}
			} else {
				$quoted_value = $dbh->quote($self->$field_name);
			}
			push @values_clauses, "$field_name = $quoted_value";
		}

		my $values_clause = join ', ', @values_clauses;

		my ($key_field_name, $key_field_value);
		
		if ($self->{_source}->{row}) {
			$key_field_name = $source->{key_field_name};
			$key_field_value = $source->{key_field_value};
			my $rows_affected = $dbh->do("update $table->{name} set $values_clause where $source->{key_field_name} = " . $dbh->quote($source->{key_field_value}) . " limit 1");

		} else {
			my $rows_affected = $dbh->do("insert into $table->{name} set $values_clause");
			($key_field_name) = @{ $table->{key_field_names} };
			$key_field_value = $dbh->last_insert_id(undef, undef, $table->{name}, $key_field_name);
		}

		$self->reload($key_field_name => $key_field_value);

		return $key_field_value;
	}
	
	sub collect {
		my ($class, %args) = @_;

		my $collection = Norma::ORM::Collection->new(
			%args,
			class => $class
		);
		return $collection;
	}

	sub delete {
		my ($self) = @_;
		my $table = $self->_table;
		my $dbh = $table->{dbh};
	
		$dbh->do("delete from $table->{name} where $self->{_source}->{key_field_name} = " . $dbh->quote($self->{_source}->{key_field_value}) . " limit 1");
	}
};

1;

__END__

=head1 NAME

Norma::ORM::Mappable - A Moose role to map database tables to objects

=head1 SYNOPSIS

  package MyApp::Customer;
  use Moose;

  with 'Norma::ORM::Mappable' => {
	dbh => $dbh,
	table_name => 'customers',
  };

  1;

  package main;

  my $customer = MyApp::Customer->new(
  	name  => ...
  	email => ...
  );
  $customer->save;

=head1 ROLE PARAMETERS

=item dbh => $dbh

A database handle from DBI->connect

=item table_name => $table_name

The name of the table which should map to this object

=item key_field_names => [$primary_key_name, ...] (optional)

A list of column names that should be seen as valid for unique lookups

=item relationships => [ { name => $name, class => $class, nature => $nature } ] (optional)

An arrayref of hashrefs, each hashref specifying a name, class, and nature.  The name will be used to create an accessor method on this object.  The class should be the class name of another object with Norma::ORM::Mappable role.  The nature is one of belongs_to, has_many, or has_one.  You may also specify foreign_key and foreign_primary_key as your naming scheme requires.  For example, our customer might have orders and a customer service rep:
  
  with 'Neocracy::ORM::Table' => {
  	...
  	relationships => [ 
  		{
			name   => 'orders',
  			class  => 'MyApp::Customer::Order',
			nature => 'has_many',
		}, {
			name        => 'customer_service_rep',
  			class       => 'MyApp::Customer::CustomerServiceRep',
			nature      => 'belongs_to',
			foreign_key => 'rep_id',
		}
	];

Objects and collections loaded through these relationships will be loaded lazily.

=head1 METHODS PROVIDED THROUGH THIS ROLE

=item new(...)

Instantiate an object in preparation for inserting a new row.  Use load to instatiate an object from an existing row in the database.

=item load(id => $primary_key_id)

Class method to instantiate an object from an existing row in the database.  

=item save

Write the object to the database, either through an insert or an updated, depending on whether the object was instantiated via new or load.

=item delete

Delete from the database the row that corresponds to this object.

=item collect(where => { $column => $value }, ...)

Class method to return a collection of objects.  See Norma::ORM::Collection for details.


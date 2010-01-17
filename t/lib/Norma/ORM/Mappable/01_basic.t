use strict;
use Test::More;
use Data::Dumper;

use DBI;
my $dbh = DBI->connect("dbi:mysql:database=unit_testing", 'tester', 'tester', { RaiseError => 1 });

use Norma::ORM::Collection;

$dbh->do("drop table if exists recipes");
$dbh->do("drop table if exists recipe_comments");
$dbh->do("drop table if exists recipe_categories");

$dbh->do(<<EOT);
CREATE TABLE `recipes` (
  `id` int(11) NOT NULL auto_increment,
  `contributor_person_id` int(11) default NULL,
  `added_date` date NOT NULL,
  `title` varchar(255) NOT NULL,
  `description` text,
  `ingredients` text,
  `instructions` text,
  `contributor_name` varchar(255) default NULL,
  `category_id` int(11),
  PRIMARY KEY  (`id`),
  FULLTEXT KEY `title` (`title`,`description`,`ingredients`,`instructions`,`contributor_name`)
) ENGINE=MyISAM CHARSET=utf8	
EOT

$dbh->do(<<EOT);
 CREATE TABLE `recipe_comments` (
  `id` int(11) NOT NULL auto_increment,
  `recipe_id` int(11) default NULL,
  `person_id` int(11) default NULL,
  `date_time` datetime default NULL,
  `text` text,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 
EOT

$dbh->do(<<EOT);
 CREATE TABLE `recipe_categories` (
  `id` int(11) NOT NULL auto_increment,
  `name` varchar(255) NOT NULL,
  PRIMARY KEY  (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=MyISAM AUTO_INCREMENT=10 DEFAULT CHARSET=utf8
EOT

package Norma::ORM::Test::Recipe;

use Moose;
use Moose::Util::TypeConstraints;

with 'Norma::ORM::Mappable' => {
	dbh => $dbh,
	table_name => 'recipes',
};

subtype RecipeTitle => as 'Str' => where { _validate_title($_) }    => message { "Titles must contain whitespace" };
subtype MySQLDate   => as 'Str' => where { m/\d{4}\-\d{2}\-\d{2}/ } => message { "Date's should look like YYYY-MM-DD" };

has '+title'      => (isa => 'RecipeTitle');
has '+added_date' => (isa => 'MySQLDate');

sub _validate_title {
	return 1 if $_ =~ /\s/;
}

1;

package main;

my $recipe = Norma::ORM::Test::Recipe->new(
	title => 'Eggs Benedict',
	ingredients => 'eggs, butter',
	instructions => 'poach eggs, etc',
	added_date => '2001-01-01',
);
$recipe->save;

my $recipe_row = $dbh->selectrow_hashref("select * from recipes where id = " . $recipe->id); 

my $expected_recipe_row = {
	'contributor_person_id' => undef,
	'instructions' => 'poach eggs, etc',
	'description' => undef,
	'category_id' => undef,
	'ingredients' => 'eggs, butter',
	'contributor_name' => undef,
	'id' => '1',
	'added_date' => '2001-01-01',
	'title' => 'Eggs Benedict'
};

is_deeply($recipe_row, $expected_recipe_row, 'row made it in okay');

my $recipe_object = Norma::ORM::Test::Recipe->load(id => $recipe->id);

is_deeply ($recipe, $recipe_object, 'we get out what we put in');

my $args = {
	title => 'Grits with Butter',
	ingredients => 'grits, water',
	instructions => 'add water',
	added_date => '2009-01-01'
};

my $errors = Norma::ORM::Test::Recipe->validate(%$args);
die Dumper $errors if $errors;

$recipe = Norma::ORM::Test::Recipe->new(%$args);
$recipe->save;

my $recipes = Norma::ORM::Test::Recipe->collect;

is($recipes->total_count, 2, 'got two objects out after putting two objects in');

is(scalar @{ $recipes->items }, 2, 'items has two objects');

$errors = Norma::ORM::Test::Recipe->validate(
	title => 'Grits',
	ingredients => 'grits, water',
	instructions => 'add water',
	added_date => '209'
);

my $expected_errors = {
	title => 'Titles must contain whitespace',
	added_date => "Date's should look like YYYY-MM-DD"
};

is_deeply($errors, $expected_errors, 'we get correct validation errors'); 

$recipes = Norma::ORM::Test::Recipe->collect(
	where => 'id = 1'
);

is ($recipes->query, "select SQL_CALC_FOUND_ROWS * from recipes where id = 1 limit 0, 50", "scalar where is untouched");

$recipes = Norma::ORM::Test::Recipe->collect(
	where => [ { id => 1, title => "Eggs%" }, "5 between 1 and 10" ]
);

is ($recipes->query, "select SQL_CALC_FOUND_ROWS * from recipes where 5 between 1 and 10 and id = '1' and title like 'Eggs%' limit 0, 50", "complicated where clause works");

$recipes = Norma::ORM::Test::Recipe->collect(
	where => { 'id >' => 0, 'title like' => 'Eggs%' }
);

is ($recipes->query, "select SQL_CALC_FOUND_ROWS * from recipes where id > '0' and title like 'Eggs%' limit 0, 50", "complicated where clause works with inline operands");

done_testing;

1;

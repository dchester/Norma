use strict;

use Test::More;
use Data::Dumper;

<<<<<<< HEAD
our $db;
=======
use Norma::ORM::Test::DB;
my $db = Norma::ORM::Test::DB->new;

$db->initialize;
my $dbh = $db->dbh;

package Norma::ORM::Test::Recipe;

use Moose;
use Moose::Util::TypeConstraints;

with 'Norma::ORM::Mappable' => {
	dbh => $dbh,
	table_name => 'recipes',
};

subtype RecipeTitle => as 'Str' => where { _validate_title($_) }    => message { "Titles must contain whitespace" };
subtype MySQLDate   => as 'Str' => where { m/\d{4}\-\d{2}\-\d{2}/ } => message { "Date's should look like YYYY-MM-DD" };
>>>>>>> 251bc2db3de714ce571130743f758811e51f7ecf

BEGIN {
	use Norma::ORM::Test::DB;
	$db = Norma::ORM::Test::DB->new;
	$db->initialize;
}

my $dbh = $db->dbh;

# create a new recipe

use Norma::ORM::Test::Recipe;

my $recipe = Norma::ORM::Test::Recipe->new(
	title => 'Eggs Benedict',
	ingredients => 'eggs, butter',
	instructions => 'poach eggs, etc',
	added_date => '2001-01-01',
);
$recipe->save;

# manually select it back out

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

# add some "likes" with map table entries

for my $i (1..8) {
	my $like = Norma::ORM::Test::Recipe::Like->new( recipe_id => $recipe->id );
	$like->save;

	my $mapping = Norma::ORM::Test::Recipe::Like::Map->new( 
		recipe_id => $recipe->id, 
		entity_like_id => $like->id,
	);
	$mapping->save;
}

# add a dummy map table entry

my $like = Norma::ORM::Test::Recipe::Like->new( recipe_id => $recipe->id );
$like->save;

my $mapping = Norma::ORM::Test::Recipe::Like::Map->new( 
	recipe_id => $recipe->id + 1, 
	entity_like_id => $like->id,
);
$mapping->save;

my $recipe_object = Norma::ORM::Test::Recipe->load(id => $recipe->id);

is_deeply($recipe, $recipe_object, 'we get out what we put in');

is( $recipe->likes->total_count, 8, "as many relevant map table entries as we expect" );

my $manual_recipe_likes = $dbh->selectall_arrayref( qq{
	select 
		entity_likes.* 
	from 
		entity_likes 
		join recipe_entity_likes_map 
			on entity_likes.id = recipe_entity_likes_map.entity_like_id
	where
		recipe_id = ?

}, { Slice => {} }, $recipe->id );

is_deeply( $manual_recipe_likes, [ $recipe->likes->items ], "relational data by map table looks good");

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
	added_date => "Dates should look like YYYY-MM-DD"
};

is_deeply($errors, $expected_errors, 'we get correct validation errors'); 

$recipes = Norma::ORM::Test::Recipe->collect(
	where => 'id = 1'
);

<<<<<<< HEAD
like($recipes->query, qr/where id = 1 limit 0, 50/, "scalar where is untouched");
=======
is ($recipes->query, "select SQL_CALC_FOUND_ROWS recipes.* from recipes where id = 1 limit 0, 50", "scalar where is untouched");
>>>>>>> 251bc2db3de714ce571130743f758811e51f7ecf

$recipes = Norma::ORM::Test::Recipe->collect(
	where => [ { id => 1, title => "Eggs" }, "5 between 1 and 10" ]
);

<<<<<<< HEAD
like($recipes->query, qr/where 5 between 1 and 10 and id = '1' and title = 'Eggs' limit 0, 50/, "complicated where clause works");
=======
is ($recipes->query, "select SQL_CALC_FOUND_ROWS recipes.* from recipes where 5 between 1 and 10 and id = '1' and title = 'Eggs' limit 0, 50", "complicated where clause works");
>>>>>>> 251bc2db3de714ce571130743f758811e51f7ecf

$recipes = Norma::ORM::Test::Recipe->collect(
	where => { 'id >' => 0, 'title like' => 'Eggs%' }
);

<<<<<<< HEAD
like($recipes->query, qr/where id > '0' and title like 'Eggs%' limit 0, 50/, "complicated where clause works with inline operands");
=======
is ($recipes->query, "select SQL_CALC_FOUND_ROWS recipes.* from recipes where id > '0' and title like 'Eggs%' limit 0, 50", "complicated where clause works with inline operands");
>>>>>>> 251bc2db3de714ce571130743f758811e51f7ecf

done_testing;

1;


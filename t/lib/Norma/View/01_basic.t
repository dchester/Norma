use Norma::View::Configuration;
use Test::More;

use Data::Dumper;

my $view = Norma::View::Configuration->new;

$view->register(
	uppercase => sub { uc shift }
);

is($view->nonexistent("message"), "message", 'nonexistent method returns its first parameter');

is($view->uppercase("message"), "MESSAGE", 'registered uc sub returns uppercase');

done_testing;

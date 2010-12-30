use inc::Module::Install;

name     'Norma';
all_from 'lib/Norma.pm';
author   q{David Chester <davidchester@gmx.net>};
license  'perl';

requires	'DBI';
requires	'Moose';
requires	'Moose::Role';
requires	'Moose::Util::TypeConstraints';
requires	'MooseX::Role::Parameterized';
requires	'MooseX::Role::Parameterized';
requires	'Lingua::EN::Inflect::Number';

build_requires	'Test::More';

test_requires	'DBD::SQLite';

default_test_target includes => ['t/lib'];

tests_recursive;

auto_install;

WriteAll;


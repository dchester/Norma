use inc::Module::Install;

name     'Norma';
all_from 'lib/Norma.pm';
author   q{David Chester <davidchester@gmx.net>};
license  'perl';

build_requires 'Test::More';

auto_install;

WriteAll;


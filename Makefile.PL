use inc::Module::Install;

name     'Array-Align';
all_from 'lib/Array/Align.pm';
author   'Jeremy G. Kahn <kahn@cpan.org>';

requires 'Heap::Simple';

build_requires 'Test::More';

auto_install;

WriteAll;


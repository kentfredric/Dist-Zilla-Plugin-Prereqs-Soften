
use strict;
use warnings;

use Test::More;

# FILENAME: 01-basic.t
# CREATED: 03/23/14 19:41:51 by Kent Fredric (kentnl) <kentfredric@gmail.com>
# ABSTRACT: Basic interface test

use lib 't/lib';
use dztest;

my $test = dztest->new();
$test->add_file( 'dist.ini', <<"EO_DISTINI");
name = E
version = 0.01
author = Kent Fredric
license = Perl_5
copyright_holder = Kent Fredric

[Prereqs]
Foo = 1

[Prereqs::Soften]
module = Foo

[MetaJSON]

[GatherDir]

EO_DISTINI
$test->add_file( 'lib/E.pm', <<'EO_EPM');
use strict;
use warnings;

package E;

# ABSTRACT: Fake dist stub

use Moose;
with 'Dist::Zilla::Role::Plugin';

1;
EO_EPM

$test->build_ok;
$test->prereqs_deeply( { runtime => { recommends => { 'Foo' => 1 } } } );

done_testing;


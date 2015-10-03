
use strict;
use warnings;

use Test::More;

# FILENAME: 01-basic.t
# CREATED: 03/23/14 19:41:51 by Kent Fredric (kentnl) <kentfredric@gmail.com>
# ABSTRACT: Basic interface test

use Test::DZil qw(simple_ini);
use Dist::Zilla::Util::Test::KENTNL 1.003002 qw( dztest );
our $TODO = "Bug #4";
my $test = dztest();
my @ini;

push @ini, [ 'Prereqs', { 'Foo' => 1 } ];
push @ini, [ 'Prereqs::Soften', { 'module' => 'Foo', 'copy_to' => 'develop', to_relationship => 'none' } ];
push @ini, ['GatherDir'];

$test->add_file( 'dist.ini', simple_ini(@ini) );
$test->add_file( 'lib/E.pm', <<'EO_EPM');
use strict;
use warnings;

package E;

# ABSTRACT: Fake dist stub

use Moose;
with 'Dist::Zilla::Role::Plugin';

1;
EO_EPM

my $e = do {
  local $@;
  eval { $test->build };
  $@;
};
ok( $e, "An exception was thrown due to invalid arguments" );

done_testing;


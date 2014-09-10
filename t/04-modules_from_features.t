
use strict;
use warnings;

use Test::More;

# FILENAME: 01-basic.t
# CREATED: 03/23/14 19:41:51 by Kent Fredric (kentnl) <kentfredric@gmail.com>
# ABSTRACT: Basic interface test

use Test::Requires 'Dist::Zilla::Plugin::OptionalFeature';
use Test::DZil qw(simple_ini);
use Dist::Zilla::Util::Test::KENTNL 1.003002 qw( dztest );

my $test = dztest();
my @ini;

push @ini, [ 'Prereqs', { 'Foo' => 1 } ];
push @ini, [ 'OptionalFeature', 'Example', { '-description' => 'An example feature', 'Foo' => 2 } ];
push @ini, [ 'Prereqs::Soften', { 'modules_from_features' => 1 } ];
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

$test->build_ok;
$test->prereqs_deeply(
  {
    runtime => { recommends => { 'Foo' => '1' } },
    develop => { requires   => { 'Foo' => '2' } },
  }
);

done_testing;


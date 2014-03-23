
use strict;
use warnings;

use Test::More;
use Path::Tiny qw(path);
use Test::Fatal;
use Test::DZil;
use JSON;

# FILENAME: 01-basic.t
# CREATED: 03/23/14 19:41:51 by Kent Fredric (kentnl) <kentfredric@gmail.com>
# ABSTRACT: Basic interface test

my $tempdir = Path::Tiny->tempdir;
my $cwd     = Path::Tiny->cwd;

note "Creating fake dist in $tempdir";

my $dist_ini = $tempdir->child('dist.ini');
my $libdir   = $tempdir->child('lib');
my $e_pm     = $libdir->child('E.pm');

$libdir->mkpath;

$dist_ini->spew(<<"EO_DISTINI");
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

$e_pm->spew(<<'EO_EPM');
use strict;
use warnings;

package E;

# ABSTRACT: Fake dist stub

use Moose;
with 'Dist::Zilla::Role::Plugin';

1;
EO_EPM

BAIL_OUT("test setup failed to copy to tempdir") if not( -e $dist_ini and -f $dist_ini );

{
  my $i = $tempdir->iterator( { recurse => 1 } );
  while ( my $path = $i->() ) {
    next if -d $path;
    note "$path : " . $path->stat->size . " " . $path->stat->mode;
  }
}

my ( $builder, $e );
is(
  $e = exception {
    $builder = Builder->from_config( { dist_root => "$tempdir" } );
  },
  undef,
  "Can load config"
);

is(
  $e = exception {
    $builder->build;
  },
  undef,
  "Can build"
);

my $build_root = path( $builder->tempdir )->child('build');
{
  my $i = $build_root->iterator( { recurse => 1 } );
  while ( my $path = $i->() ) {
    next if -d $path;
    note "$path : " . $path->stat->size . " " . $path->stat->mode;
  }
}

ok( -e $build_root->child('META.json'), 'META.json emitted' );

my $meta = JSON->new->utf8(1)->decode( $build_root->child('META.json')->slurp_utf8 );

note explain $meta;

is_deeply( $meta->{prereqs}, { runtime => { recommends => { 'Foo' => 1 } } }, "Prereqs match expected", );

done_testing;


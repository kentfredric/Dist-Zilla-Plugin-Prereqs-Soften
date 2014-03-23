use 5.008;    # utf8
use strict;
use warnings;
use utf8;

package dztest;

# ABSTRACT: Shared dist testing logic for easy dzil things

# AUTHORITY

use Moose;
use Test::DZil;
use Test::Fatal;
use JSON;
use Test::More;
use Path::Tiny qw(path);

has files => (
  is   => ro =>,
  lazy => 1,
  default => sub { return {}; },
);

has tempdir => (
  is      => ro =>,
  lazy    => 1,
  default => sub {
    my $tempdir = Path::Tiny->tempdir;
    note "Creating fake dist in $tempdir";
    return $tempdir;
  },
);

has builder => (
  is         => ro =>,
  lazy_build => 1,
);

sub add_file {
  my ( $self, $path, $content ) = @_;
  my $target = $self->tempdir->child($path);
  $target->parent->mkpath;
  $target->spew($content);
  $self->files->{ $target->relative( $self->tempdir ) } = $target;
  return;
}

sub has_source_file {
  my ( $self, $path ) = @_;
  return unless -e $self->tempdir->child($path);
  return -f $self->tempdir->child($path);
}

sub _build_builder {
  my ($self) = @_;
  return Builder->from_config( { dist_root => q[] . $self->tempdir } );
}

sub configure {
  my ($self) = @_;
  $self->builder;
}

sub safe_configure {
  my ($self) = @_;
  return exception {
    $self->configure;
  };
}

sub build {
  my ($self) = @_;
  $self->builder->build;
}

sub safe_build {
  my ($self) = @_;
  return exception {
    $self->build;
  };
}

sub _build_root {
  my ($self) = @_;
  return path( $self->builder->tempdir )->child('build');
}

sub _note_path_files {
  my ( $self, $path ) = @_;
  my $i = path($path)->iterator( { recurse => 1 } );
  while ( my $path = $i->() ) {
    next if -d $path;
    note "$path : " . $path->stat->size . " " . $path->stat->mode;
  }
}

sub note_tempdir_files {
  my ($self) = @_;
  $self->_note_path_files( $self->tempdir );
}

sub note_builddir_files {
  my ($self) = @_;
  $self->_note_path_files( $self->_build_root );
}

sub built_json_file {
  my ($self) = @_;
  return $self->_build_root->child('META.json');
}

sub built_json {
  my ($self) = @_;
  return JSON->new->utf8(1)->decode( $self->built_json_file->slurp_utf8 );
}

sub build_ok {
  my ($self) = @_;
  return subtest 'Configure and build' => sub {
    for my $file ( values %{ $self->files } ) {
      next if -e $file and -f $file;
      BAIL_OUT("expected file $file failed to add to tempdir");
    }
    $self->note_tempdir_files;

    is( $self->safe_configure, undef, "Can load config" );

    is( $self->safe_build, undef, "Can build" );

    $self->note_builddir_files;
  };
}

sub prereqs_deeply {
  my ( $self, $prereqs ) = @_;
  return subtest "META.json prereqs comparison" => sub {
    ok( -e $self->built_json_file, 'META.json emitted' );
    my $meta = $self->built_json;
    note explain $meta->{prereqs};
    is_deeply( $meta->{prereqs}, $prereqs, "Prereqs match expected set" );
  };
}

1;


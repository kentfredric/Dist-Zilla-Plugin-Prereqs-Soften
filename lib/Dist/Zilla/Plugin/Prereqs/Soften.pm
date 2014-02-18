use 5.008;    # utf-8
use strict;
use warnings;
use utf8;

package Dist::Zilla::Plugin::Prereqs::Soften;

# ABSTRACT: Downgrade listed dependencies to recommendations if present.

# AUTHORITY

use Moose qw( with has around );
use MooseX::Types::Moose qw( ArrayRef HashRef Str );
with 'Dist::Zilla::Role::PrereqSource';

=head1 SYNOPSIS

    [Prereqs::Soften]
    module = Foo
    module = Bar

This module iterates C<build>, C<require> and C<test> dependency lists
and migrates dependencies found in C<.requires> and demotes them to C<.recommends>

=cut

=attr C<modules>

A C<multi-value> argument that specifies a module name to soften in C<prereqs>.

=cut

has 'modules' => (
  is => ro =>,
  isa => ArrayRef [Str],
  lazy    => 1,
  default => sub { [] },
);

=attr C<to_relationship>

The output relationship kind.

B<Default:>

    'recommends'

B<Valid Values:>

    'recommends', 'suggests', 'requires', 'conflicts'

Though the last two are reserved for people with C<< $num_feet > 2 >> or with shotguns that only fire blanks.

=cut

use Moose::Util::TypeConstraints qw(enum);

has 'to_relationship' => (
  is => ro =>,
  isa => enum( [qw(requires recommends suggests conflicts)] ),
  lazy    => 1,
  default => sub { 'recommends' },
);

no Moose::Util::TypeConstraints;

has '_modules_hash' => (
  is      => ro                   =>,
  isa     => HashRef,
  lazy    => 1,
  builder => _build__modules_hash =>,
);
sub mvp_multivalue_args { return qw(modules) }
sub mvp_aliases { return { 'module' => 'modules' } }

sub _build__modules_hash {
  my $self = shift;
  return { map { ( $_, 1 ) } @{ $self->modules } };
}

sub _user_wants_softening_on {
  my ( $self, $module ) = @_;
  return exists $self->_modules_hash->{$module};
}
around dump_config => sub {
  my ( $orig, $self ) = @_;
  my $config      = $self->$orig;
  my $this_config = {
    modules         => $self->modules,
    to_relationship => $self->to_relationship,
  };
  $config->{ q{} . __PACKAGE__ } = $this_config;
  return $config;
};

sub _soften_prereqs {
  my ( $self, $conf ) = @_;
  my $prereqs = $self->zilla->prereqs;

  my $source_reqs = $prereqs->requirements_for( $conf->{from_phase}, $conf->{from_relation} );
  my $target_reqs = $prereqs->requirements_for( $conf->{to_phase},   $conf->{to_relation} );

  for my $module ( $source_reqs->required_modules ) {
    next unless $self->_user_wants_softening_on($module);
    my $reqstring = $source_reqs->requirements_for_module($module);
    $source_reqs->clear_requirement($module);
    $target_reqs->add_string_requirement( $module, $reqstring );
  }
  return $self;
}

sub register_prereqs {
  my ($self) = @_;

  for my $phase (qw( build test runtime )) {
    for my $relation (qw( requires )) {
      $self->_soften_prereqs(
        {
          from_phase    => $phase,
          from_relation => $relation,
          to_phase      => $phase,
          to_relation   => $self->to_relationship,
        },
      );
    }
  }
  return;
}

=begin Pod::Coverage

mvp_aliases
mvp_multivalue_args
register_prereqs

=cut

__PACKAGE__->meta->make_immutable;
no Moose;

1;


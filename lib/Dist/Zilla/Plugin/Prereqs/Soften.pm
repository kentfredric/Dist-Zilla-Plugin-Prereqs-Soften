use 5.008;    # utf-8
use strict;
use warnings;
use utf8;

package Dist::Zilla::Plugin::Prereqs::Soften;
$Dist::Zilla::Plugin::Prereqs::Soften::VERSION = '0.300000';
# ABSTRACT: Downgrade listed dependencies to recommendations if present.

our $AUTHORITY = 'cpan:KENTNL'; # AUTHORITY

use Moose qw( with has around );
use MooseX::Types::Moose qw( ArrayRef HashRef Str );
with 'Dist::Zilla::Role::PrereqSource';




















has 'modules' => (
  is => ro =>,
  isa => ArrayRef [Str],
  lazy    => 1,
  default => sub { [] },
);

















use Moose::Util::TypeConstraints qw(enum);

has 'to_relationship' => (
  is => ro =>,
  isa => enum( [qw(requires recommends suggests conflicts)] ),
  lazy    => 1,
  default => sub { 'recommends' },
);

no Moose::Util::TypeConstraints;
































has 'copy_to' => (
  is => ro =>,
  isa => ArrayRef [Str],
  lazy    => 1,
  default => sub { [] },
);

has '_modules_hash' => (
  is      => ro                   =>,
  isa     => HashRef,
  lazy    => 1,
  builder => _build__modules_hash =>,
);
sub mvp_multivalue_args { return qw(modules copy_to) }
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
    copy_to         => $self->copy_to,
  };
  $config->{ q{} . __PACKAGE__ } = $this_config;
  return $config;
};

sub _soften_prereqs {
  my ( $self, $conf ) = @_;
  my $prereqs = $self->zilla->prereqs;

  my $source_reqs = $prereqs->requirements_for( $conf->{from_phase}, $conf->{from_relation} );

  my @target_reqs;

  for my $target ( @{ $conf->{to} } ) {
    push @target_reqs, $prereqs->requirements_for( $target->{phase}, $target->{relation} );
  }

  for my $module ( $source_reqs->required_modules ) {
    next unless $self->_user_wants_softening_on($module);
    my $reqstring = $source_reqs->requirements_for_module($module);
    $source_reqs->clear_requirement($module);
    for my $target (@target_reqs) {
      $target->add_string_requirement( $module, $reqstring );
    }
  }
  return $self;
}

sub register_prereqs {
  my ($self) = @_;

  for my $phase (qw( build test runtime )) {
    for my $relation (qw( requires )) {
      my $to = [];
      push @$to, { phase => $phase, relation => $self->to_relationship };
      for my $copy ( @{ $self->copy_to } ) {
        next unless ( my ( $copy_phase, $copy_rel ) = $copy =~ /\A([^.]+)[.](.+)\z/m );
        push @{$to}, { phase => $copy_phase, relation => $copy_rel };
      }
      $self->_soften_prereqs(
        {
          from_phase    => $phase,
          from_relation => $relation,
          to            => $to,
        },
      );
    }
  }
  return;
}









__PACKAGE__->meta->make_immutable;
no Moose;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Dist::Zilla::Plugin::Prereqs::Soften - Downgrade listed dependencies to recommendations if present.

=head1 VERSION

version 0.300000

=head1 SYNOPSIS

    [Prereqs::Soften]
    module = Foo
    module = Bar

This module iterates C<build>, C<require> and C<test> dependency lists and migrates dependencies found in C<.requires> and
demotes them to C<.recommends>

Optionally, it can L<< duplicate softened dependencies to other locations|/copy_to >>

=head1 ATTRIBUTES

=head2 C<modules>

A C<multi-value> argument that specifies a module name to soften in C<prereqs>.

=head2 C<to_relationship>

The output relationship kind.

B<Default:>

    'recommends'

B<Valid Values:>

    'recommends', 'suggests', 'requires', 'conflicts'

Though the last two are reserved for people with C<< $num_feet > 2 >> or with shotguns that only fire blanks.

=head2 C<copy_to>

Additional places to copy the dependency to:

B<Default:>

    []

B<Example:>

    [Prereqs::Soften]
    copy_to         = develop.requires
    to_relationship = recommends
    module          = Foo

This in effect means:

    remove from: runtime.requires
        → add to: develop.requires
        → add to: runtime.recommends

    remove from: test.requires
        → add to: develop.requires
        → add to: test.recommends

     remove from: build.requires
        → add to: develop.requires
        → add to: build.recommends

=for Pod::Coverage mvp_aliases
mvp_multivalue_args
register_prereqs

=head1 AUTHOR

Kent Fredric <kentfredric@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Kent Fredric <kentfredric@gmail.com>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

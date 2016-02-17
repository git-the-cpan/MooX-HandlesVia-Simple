use strict;
use warnings FATAL => 'all';

package MooX::HandlesVia::Simple;

# ABSTRACT: A MooX::HandlesVia fast version, with no check, inserting code references

our $VERSION = '0.001'; # TRIAL VERSION

our $AUTHORITY = 'cpan:JDDPAUSE'; # AUTHORITY

use Moo qw//;
use Moo::Role qw//;
use Types::Standard -all;
use Type::Utils -all;
use Data::Perl::Role::String qw//;
use Data::Perl::Role::Number qw//;
use Data::Perl::Role::Bool qw//;
use Data::Perl::Role::Code qw//;

my $Handles_Via = Enum[qw/Array Hash String Number Bool Code/];

#
# import() copied from MooX::HandlesVia 0.001008
#
sub import {
  my ($class) = @_;

  my $target = caller;
  if (my $has = $target->can('has')) {
    my $isRole = Moo::Role->is_role($target);
    my $newsub = sub {
        $has->(_process_has($target, $isRole, @_));
    };

    if ($isRole) {
      Moo::Role::_install_tracked($target, 'has', $newsub);
    } else {
      Moo::_install_tracked($target, 'has', $newsub);
    }
  }
}

sub _process_has {
  my ($target, $isRole) = (shift, shift);
  my ($name, %opts) = @_;

  my $handles_via   = delete($opts{handles_via});
  my $handles       = delete($opts{handles}) // {};
  my $handles_dirty = delete($opts{handles_dirty}) // {};
  #
  # We support only the handles_via => 'XXX' and handles[_dirty] => {} notations
  #
  return @_ unless $Handles_Via->check($handles_via);
  return @_ unless HashRef->check($handles);
  return @_ unless HashRef->check($handles_dirty);
  #
  # handles has priority over handles_dirty
  #
  map { delete $handles_dirty->{$_} } keys %{$handles};
  #
  # Purify the handles
  #
  foreach my $hash ($handles, $handles_dirty) {
    map { delete $hash->{$_} unless Str->check($_) && length($_) && Str->check($hash->{$_}) && length($hash->{$_}) } keys %{$hash}
  }
  #
  # Generate stubs
  #
  if    ($handles_via eq 'Array')  { _handles_via_Array ($target, $isRole, $name, $handles, $handles_dirty) }
  elsif ($handles_via eq 'Hash')   { _handles_via_Hash  ($target, $isRole, $name, $handles, $handles_dirty) }
  elsif ($handles_via eq 'String') { _handles_via_String($target, $isRole, $name, $handles, $handles_dirty) }
  elsif ($handles_via eq 'Number') { _handles_via_Number($target, $isRole, $name, $handles, $handles_dirty) }
  elsif ($handles_via eq 'Bool')   { _handles_via_Bool  ($target, $isRole, $name, $handles, $handles_dirty) }
  elsif ($handles_via eq 'Code')   { _handles_via_Code  ($target, $isRole, $name, $handles, $handles_dirty) }
  #
  # Return arguments as is
  #
  return ($name, %opts)
}

my $_FIRST  = $[;
my $_SECOND = $[+1;
my $_THIRD  = $[+2;
my $secondArgument = "\$_[$_SECOND]";
my $thirdArgument = "\$_[$_THIRD]";
my $allArguments = "\@_[$_SECOND..\$#_]";

sub _handles_via_Array {
  my ($target, $isRole, $name, $handles, $handles_dirty) = @_;

  foreach my $hash ($handles, $handles_dirty) {
    my $accessor = ($hash == $handles) ? $name : "{$name}";
    my $member = "\$_[$_FIRST]" . '->' . "$accessor";
    my $value = $member . '->' . "[$secondArgument]";

    while (my ($stubname, $alias) = each %{$hash}) {
      my $coderef = undef;
      if    ($alias eq 'count')       { $coderef = eval "sub { return CORE::scalar(\@{$member})                                                  }" }
      elsif ($alias eq 'is_empty')    { $coderef = eval "sub { return CORE::scalar(\@{$member}) ? 0 : 1                                          }" }
      elsif ($alias eq 'get')         { $coderef = eval "sub { return $value                                                                     }" }
      elsif ($alias eq 'pop')         { $coderef = eval "sub { return CORE::pop(\@{$member})                                                     }" }
      elsif ($alias eq 'push')        { $coderef = eval "sub { return CORE::push(\@{$member}, $allArguments)                                     }" }
      elsif ($alias eq 'shift')       { $coderef = eval "sub { return CORE::shift(\@{$member})                                                   }" }
      elsif ($alias eq 'unshift')     { $coderef = eval "sub { return CORE::unshift(\@{$member})                                                 }" }
      elsif ($alias eq 'clear')       { $coderef = eval "sub { return \@{$member} = ()                                                           }" }
      elsif ($alias eq 'set')         { $coderef = eval "sub { return $value = $thirdArgument                                                    }" }
      elsif ($alias eq 'accessor')    { $coderef = eval "sub { return (scalar(\@_) == 2) ? $value : $value = $thirdArgument                      }" }
      elsif ($alias eq 'elements')    { $coderef = eval "sub { return \@{$member}                                                                }" }
      elsif ($alias eq 'flatten')     { $coderef = eval "sub { return \@{$member}                                                                }" }
      #
      # The followings will do type promotion if needed, you are warned
      #
      elsif ($alias eq 'join')        { $coderef = eval "sub { return CORE::join($secondArgument // ',', \@{$member})                            }" }
      elsif ($alias eq 'append')      { $coderef = eval "sub { return $value .= $thirdArgument                                                   }" }
      elsif ($alias eq 'add')         { $coderef = eval "sub { return $value += $thirdArgument                                                   }" }
      elsif ($alias eq 'sub')         { $coderef = eval "sub { return $value -= $thirdArgument                                                   }" }
      elsif ($alias eq 'div')         { $coderef = eval "sub { return $value /= $thirdArgument                                                   }" }
      elsif ($alias eq 'mul')         { $coderef = eval "sub { return $value *= $thirdArgument                                                   }" }

      warn "$stubname => $alias: $@" if $@;

      _commit($isRole, $target, $stubname, $coderef) if (defined($coderef));
    }
  }
}

sub _commit {
  my ($isRole, $target, $stubname, $coderef) = @_;

  if ($isRole) {
    Moo::Role::_install_tracked($target, $stubname, $coderef);
  } else {
    Moo::_install_tracked($target, $stubname, $coderef);
  }
}

sub _handles_via_Hash {
  my ($target, $isRole, $name, $handles, $handles_dirty) = @_;

  foreach my $hash ($handles, $handles_dirty) {
    my $accessor = ($hash == $handles) ? $name : "{$name}";
    my $member = "\$_[$_FIRST]" . '->' . "$accessor";
    my $value = $member . '->' . "{$secondArgument}";

    while (my ($stubname, $alias) = each %{$hash}) {
      my $coderef = undef;
      if    ($alias eq 'get')         { $coderef = eval "sub { return $value                                                                     }" }
      elsif ($alias eq 'set')         { $coderef = eval "sub { return $value = $thirdArgument                                                    }" }
      elsif ($alias eq 'delete')      { $coderef = eval "sub { return CORE::delete($value)                                                       }" }
      elsif ($alias eq 'keys')        { $coderef = eval "sub { return CORE::keys(\%{$member})                                                    }" }
      elsif ($alias eq 'exists')      { $coderef = eval "sub { return CORE::exists($value)                                                       }" }
      elsif ($alias eq 'defined')     { $coderef = eval "sub { return CORE::defined($value)                                                      }" }
      elsif ($alias eq 'values')      { $coderef = eval "sub { return CORE::values \%{$member}                                                   }" }
      elsif ($alias eq 'kv')          { $coderef = eval "sub { return \%{$member}                                                                }" }
      elsif ($alias eq 'clear')       { $coderef = eval "sub { return \%{$member} = ()                                                           }" }
      elsif ($alias eq 'count')       { $coderef = eval "sub { return CORE::scalar(CORE::keys(\%{$member}))                                      }" }
      elsif ($alias eq 'is_empty')    { $coderef = eval "sub { return \%{$member} ? 0 : 1                                                        }" }
      elsif ($alias eq 'accessor')    { $coderef = eval "sub { return (scalar(\@_) == 2) ? $value : $value = $thirdArgument                      }" }
      #
      # The followings will do type promotion if needed, you are warned
      #
      elsif ($alias eq 'append')      { $coderef = eval "sub { return $value .= $thirdArgument                                                   }" }
      elsif ($alias eq 'add')         { $coderef = eval "sub { return $value += $thirdArgument                                                   }" }
      elsif ($alias eq 'sub')         { $coderef = eval "sub { return $value -= $thirdArgument                                                   }" }
      elsif ($alias eq 'div')         { $coderef = eval "sub { return $value /= $thirdArgument                                                   }" }
      elsif ($alias eq 'mul')         { $coderef = eval "sub { return $value *= $thirdArgument                                                   }" }

      warn "$stubname => $alias: $@" if $@;

      _commit($isRole, $target, $stubname, $coderef) if (defined($coderef));
    }
  }
}
my %STRING_REFS = ();
foreach (qw/inc append prepend replace match chop chomp clear length substr/) {
  if (my $coderef = Data::Perl::Role::String->can($_)) {
    $STRING_REFS{$_} = $coderef;
  }
}
sub _handles_via_String {
  my ($target, $isRole, $name, $handles, $handles_dirty) = @_;

  foreach my $hash ($handles, $handles_dirty) {
    while (my ($stubname, $alias) = each %{$hash}) {
      my $coderef = $STRING_REFS{$alias};
      next if (! $coderef);
      _commit($isRole, $target, $stubname, $coderef) if (defined($coderef));
    }
  }
}

my %NUMBER_REFS = ();
foreach (qw/add sub mul div mod abs/) {
  if (my $coderef = Data::Perl::Role::Number->can($_)) {
    $NUMBER_REFS{$_} = $coderef;
  }
}
sub _handles_via_Number {
  my ($target, $isRole, $name, $handles, $handles_dirty) = @_;

  foreach my $hash ($handles, $handles_dirty) {
    while (my ($stubname, $alias) = each %{$hash}) {
      my $coderef = $NUMBER_REFS{$alias};
      next if (! $coderef);
      _commit($isRole, $target, $stubname, $coderef) if (defined($coderef));
    }
  }
}

my %BOOL_REFS = ();
foreach (qw/set unset toggle/) {
  if (my $coderef = Data::Perl::Role::Bool->can($_)) {
    $BOOL_REFS{$_} = $coderef;
  }
}
sub _handles_via_Bool {
  my ($target, $isRole, $name, $handles, $handles_dirty) = @_;

  foreach my $hash ($handles, $handles_dirty) {
    while (my ($stubname, $alias) = each %{$hash}) {
      my $coderef = $BOOL_REFS{$alias};
      next if (! $coderef);
      _commit($isRole, $target, $stubname, $coderef) if (defined($coderef));
    }
  }
}

my %CODE_REFS = ();
foreach (qw/execute/) {
  if (my $coderef = Data::Perl::Role::Code->can($_)) {
    $CODE_REFS{$_} = $coderef;
  }
}
sub _handles_via_Code {
  my ($target, $isRole, $name, $handles, $handles_dirty) = @_;

  foreach my $hash ($handles, $handles_dirty) {
    while (my ($stubname, $alias) = each %{$hash}) {
      my $coderef = $CODE_REFS{$alias};
      next if (! $coderef);
      _commit($isRole, $target, $stubname, $coderef) if (defined($coderef));
    }
  }
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

MooX::HandlesVia::Simple - A MooX::HandlesVia fast version, with no check, inserting code references

=head1 VERSION

version 0.001

=for :stopwords cpan testmatrix url annocpan anno bugtracker rt cpants kwalitee diff irc mailto metadata placeholders metacpan

=head1 SUPPORT

=head2 Bugs / Feature Requests

Please report any bugs or feature requests through the issue tracker
at L<https://rt.cpan.org/Public/Dist/Display.html?Name=MooX-HandlesVia-Simple>.
You will be notified automatically of any progress on your issue.

=head2 Source Code

This is open source software.  The code repository is available for
public review and contribution under the terms of the license.

L<https://github.com/jddurand/moox-handlesvia-simple>

  git clone git://github.com/jddurand/moox-handlesvia-simple.git

=head1 AUTHOR

Jean-Damien Durand <jeandamiendurand@free.fr>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2016 by Jean-Damien Durand.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

package Mojolicious::Plugin::FormRequest::Rule;
use Mojo::Base -base, -signatures;

has 'kind';
has 'args';

sub in ($class, $values) {
  return $class->new(kind => 'in', args => $values);
}

sub not_in ($class, $values) {
  return $class->new(kind => 'not_in', args => $values);
}

sub unique ($class, $table, $column) {
  return $class->new(kind => 'unique', args => [$table, $column]);
}

sub exists ($class, $table, $column) {
  return $class->new(kind => 'exists', args => [$table, $column]);
}

sub ignore ($self, $id, $id_column = 'id') {
  push @{ $self->args }, $id, $id_column;
  return $self;
}

sub message ($self) {
  my $kind = $self->kind;
  return 'is not in the allowed list' if $kind eq 'in';
  return 'is in the forbidden list'   if $kind eq 'not_in';
  return 'has already been taken'     if $kind eq 'unique';
  return 'does not exist'             if $kind eq 'exists';
  return 'is invalid';
}

sub validate ($self, $value, $args, $params, $ctx) {
  my $kind = $self->kind;
  my $a    = $self->args;
  if ($kind eq 'in') {
    for my $v (@$a) {
      return 1 if defined $value && $v eq $value;
    }
    return 0;
  }
  if ($kind eq 'not_in') {
    for my $v (@$a) {
      return 0 if defined $value && $v eq $value;
    }
    return 1;
  }
  if ($kind eq 'unique') {
    my ($table, $column, $id, $id_column) = @$a;
    return $ctx->{db}->unique($table, $column, $value, $id, $id_column) ? 1 : 0;
  }
  if ($kind eq 'exists') {
    my ($table, $column) = @$a;
    return $ctx->{db}->exists($table, $column, $value) ? 1 : 0;
  }
  return 0;
}

1;

__END__

=head1 NAME

Mojolicious::Plugin::FormRequest::Rule - Fluent rule-object constructors

=head1 DESCRIPTION

=head1 TRUSTED

=over 4

=item exists

=item ignore

=item in

=item message

=item not_in

=item unique

=item validate

=back

=cut

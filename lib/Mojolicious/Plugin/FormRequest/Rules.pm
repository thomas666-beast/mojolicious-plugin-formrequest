package Mojolicious::Plugin::FormRequest::Rules;
use Mojo::Base -base, -signatures;

my %RULES;

sub register_rule ($class, $name, $code) {
  $RULES{$name} = $code;
}

sub get ($class, $name) {
  return $RULES{$name};
}

sub _looks_numeric ($v) {
  return defined $v && $v =~ /\A-?(?:\d+\.?\d*|\.\d+)\z/;
}
sub _size_of ($v) {
  return _looks_numeric($v) ? $v + 0 : length($v // '');
}

__PACKAGE__->register_rule('required' => sub ($value, $args, $params, $ctx) {
  return defined $value && $value ne '' ? 1 : 0;
});

__PACKAGE__->register_rule('nullable' => sub ($value, $args, $params, $ctx) { 1 });

__PACKAGE__->register_rule('string' => sub ($value, $args, $params, $ctx) {
  return !ref $value;
});

__PACKAGE__->register_rule('password' => sub ($value, $args, $params, $ctx) {
  return !ref $value && defined $value && $value ne '' ? 1 : 0;
});

__PACKAGE__->register_rule('integer' => sub ($value, $args, $params, $ctx) {
  return $value =~ /\A-?\d+\z/ ? 1 : 0;
});

__PACKAGE__->register_rule('numeric' => sub ($value, $args, $params, $ctx) {
  return _looks_numeric($value) ? 1 : 0;
});

__PACKAGE__->register_rule('boolean' => sub ($value, $args, $params, $ctx) {
  return (defined $value && $value =~ /\A(?:0|1|true|false)\z/i) ? 1 : 0;
});

__PACKAGE__->register_rule('email' => sub ($value, $args, $params, $ctx) {
  return $value =~ /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/ ? 1 : 0;
});

__PACKAGE__->register_rule('url' => sub ($value, $args, $params, $ctx) {
  return $value =~ m{\Ahttps?://[^\s]+\z} ? 1 : 0;
});

__PACKAGE__->register_rule('ip' => sub ($value, $args, $params, $ctx) {
  return $value =~ /\A(?:\d{1,3}\.){3}\d{1,3}\z/ ? 1 : 0;
});

__PACKAGE__->register_rule('uuid' => sub ($value, $args, $params, $ctx) {
  return $value =~ /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i ? 1 : 0;
});

__PACKAGE__->register_rule('alpha' => sub ($value, $args, $params, $ctx) {
  return $value =~ /\A[a-zA-Z]+\z/ ? 1 : 0;
});

__PACKAGE__->register_rule('alpha_num' => sub ($value, $args, $params, $ctx) {
  return $value =~ /\A[a-zA-Z0-9]+\z/ ? 1 : 0;
});

__PACKAGE__->register_rule('alpha_dash' => sub ($value, $args, $params, $ctx) {
  return $value =~ /\A[a-zA-Z0-9_-]+\z/ ? 1 : 0;
});

__PACKAGE__->register_rule('min' => sub ($value, $args, $params, $ctx) {
  my $n = $args->[0] // 0;
  return _size_of($value) >= $n ? 1 : 0;
});

__PACKAGE__->register_rule('max' => sub ($value, $args, $params, $ctx) {
  my $n = $args->[0] // 0;
  return _size_of($value) <= $n ? 1 : 0;
});

__PACKAGE__->register_rule('between' => sub ($value, $args, $params, $ctx) {
  my ($lo, $hi) = @$args;
  my $size = _size_of($value);
  return ($size >= $lo && $size <= $hi) ? 1 : 0;
});

__PACKAGE__->register_rule('size' => sub ($value, $args, $params, $ctx) {
  my $n = $args->[0] // 0;
  return _size_of($value) == $n ? 1 : 0;
});

__PACKAGE__->register_rule('in' => sub ($value, $args, $params, $ctx) {
  return grep { defined $value && $_ eq $value } @$args;
});

__PACKAGE__->register_rule('not_in' => sub ($value, $args, $params, $ctx) {
  return grep { defined $value && $_ eq $value } @$args ? 0 : 1;
});

__PACKAGE__->register_rule('regex' => sub ($value, $args, $params, $ctx) {
  my $pattern = $args->[0] // '';
  $pattern =~ s{^/|/$}{}g;
  return eval { $value =~ qr/$pattern/ } ? 1 : 0;
});

__PACKAGE__->register_rule('confirmed' => sub ($value, $args, $params, $ctx) {
  return 1;
});

__PACKAGE__->register_rule('same' => sub ($value, $args, $params, $ctx) {
  my $other = $args->[0] // '';
  return ($params->{$other} // '') eq $value ? 1 : 0;
});

__PACKAGE__->register_rule('different' => sub ($value, $args, $params, $ctx) {
  my $other = $args->[0] // '';
  return ($params->{$other} // '') ne $value ? 1 : 0;
});

__PACKAGE__->register_rule('date' => sub ($value, $args, $params, $ctx) {
  return $value =~ /\A\d{4}-\d{2}-\d{2}\z/ ? 1 : 0;
});

__PACKAGE__->register_rule('array' => sub ($value, $args, $params, $ctx) {
  return ref $value eq 'ARRAY' ? 1 : 0;
});

__PACKAGE__->register_rule('json' => sub ($value, $args, $params, $ctx) {
  require JSON::PP;
  return eval { JSON::PP->new->decode($value); 1 } ? 1 : 0;
});

__PACKAGE__->register_rule('distinct' => sub ($value, $args, $params, $ctx) {
  return 1 unless ref $value eq 'ARRAY';
  my %seen;
  for my $v (@$value) {
    return 0 if $seen{$v}++;
  }
  return 1;
});

__PACKAGE__->register_rule('prohibited' => sub ($value, $args, $params, $ctx) {
  return !defined $value || $value eq '' ? 1 : 0;
});

__PACKAGE__->register_rule('required_if' => sub ($value, $args, $params, $ctx) {
  my ($other, $expected) = @$args;
  my $v = $params->{$other};
  return 1 unless defined $v && $v eq $expected;
  return defined $value && $value ne '' ? 1 : 0;
});

__PACKAGE__->register_rule('required_unless' => sub ($value, $args, $params, $ctx) {
  my ($other, $expected) = @$args;
  my $v = $params->{$other};
  return 1 if defined $v && $v eq $expected;
  return defined $value && $value ne '' ? 1 : 0;
});

__PACKAGE__->register_rule('required_with' => sub ($value, $args, $params, $ctx) {
  my $present = grep { defined $params->{$_} && $params->{$_} ne '' } @$args;
  return 1 unless $present;
  return defined $value && $value ne '' ? 1 : 0;
});

__PACKAGE__->register_rule('required_without' => sub ($value, $args, $params, $ctx) {
  my $missing = grep { !defined $params->{$_} || $params->{$_} eq '' } @$args;
  return 1 unless $missing;
  return defined $value && $value ne '' ? 1 : 0;
});

__PACKAGE__->register_rule('exists' => sub ($value, $args, $params, $ctx) {
  my ($table, $column) = @$args;
  $column //= 'id';
  return $ctx->{db}->exists($table, $column, $value) ? 1 : 0;
});

__PACKAGE__->register_rule('unique' => sub ($value, $args, $params, $ctx) {
  my ($table, $column, $except_id, $id_column) = @$args;
  $column    //= 'id';
  $id_column //= 'id';
  return $ctx->{db}->unique($table, $column, $value, $except_id, $id_column) ? 1 : 0;
});

1;

__END__

=head1 NAME

Mojolicious::Plugin::FormRequest::Rules - Built-in validation rules

=head1 DESCRIPTION

Registry of all validation rules used by
L<Mojolicious::Plugin::FormRequest::Validator>.

=head1 TRUSTED

=over 4

=item get

=item register_rule

=back

=cut


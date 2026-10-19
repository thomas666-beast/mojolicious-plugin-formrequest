package Mojolicious::Plugin::FormRequest::Validator;
use Mojo::Base -base, -signatures;

use Mojolicious::Plugin::FormRequest::Rules;
use Mojolicious::Plugin::FormRequest::Db;

has 'c';
has 'request_class';

sub validate ($self) {
  my $c     = $self->c;
  my $class = $self->request_class;
  my $req   = $class->new;

  unless ($req->authorize($c)) {
    return { ok => 0, status => 403, errors => { _authorization => 'Forbidden' } };
  }

  my $rules    = $req->rules($c)    // {};
  my $messages = $req->messages($c) // {};
  my $attrs    = $req->attributes($c) // {};

  my $flat   = $c->req->params->to_hash;
  my $params = $self->_inflate($flat);
  $params = { %$flat, %$params };

  my $db  = Mojolicious::Plugin::FormRequest::Db->new(
    c        => $c,
    resolver => $c->app->config->{FormRequest}{db},
  );
  my $ctx = { c => $c, db => $db };

  my %errors;
  my %validated;

  for my $pattern (keys %$rules) {
    my @targets = $self->_resolve($pattern, $flat);

    unless (@targets) {
      if ($pattern !~ /\*/ && $rules->{$pattern} =~ /\brequired\b/) {
        $errors{$pattern} = $self->_message($pattern, 'required', $messages, $attrs);
      }
      next;
    }

    for my $pair (@targets) {
      my ($field_name, $value) = @$pair;
      my $rule_str = $rules->{$pattern};

      next if $rule_str =~ /\bsometimes\b/ && !defined $value;

      my @rule_list = split /\|/, $rule_str;
      my $nullable  = grep { $_ eq 'nullable' } @rule_list;
      my $missing   = !defined $value || $value eq '';

      if ($nullable && $missing) {
        $validated{$field_name} = $value;
        next;
      }

      my $field_failed = 0;

      for my $rule (@rule_list) {
        next if $rule eq 'nullable' || $rule eq 'sometimes';

        my ($name, $argstr) = split /:/, $rule, 2;
        my @args = defined $argstr ? split /,/, $argstr : ();

        if ($name eq 'required') {
          if ($missing) {
            $errors{$field_name} = $self->_message($field_name, 'required', $messages, $attrs);
            $field_failed = 1;
            last;
          }
          next;
        }

        next if $missing;

        if ($name eq 'confirmed') {
          my $confirm = $params->{"${field_name}_confirmation"} // '';
          unless ($confirm eq $value) {
            $errors{$field_name} = $self->_message($field_name, 'confirmed', $messages, $attrs);
            $field_failed = 1;
            last;
          }
          next;
        }

        my $code = Mojolicious::Plugin::FormRequest::Rules->get($name);
        next unless $code;

        unless ($code->($value, \@args, $params, $ctx)) {
          $errors{$field_name} = $self->_message($field_name, $name, $messages, $attrs, \@args);
          $field_failed = 1;
          last;
        }
      }

      $validated{$field_name} = $value unless $field_failed;
    }
  }

  return { ok => 0, status => 422, errors => \%errors } if %errors;
  return { ok => 1, data => \%validated };
}

sub _inflate ($self, $flat) {
  my %out;
  for my $key (sort keys %$flat) {
    my @parts = $key =~ /\G(?:^|\]\[?|\[)([^\[\]]+)/g;
    next unless @parts;
    my $cur = \%out;
    for my $i (0 .. $#parts) {
      my $p = $parts[$i];
      if ($i == $#parts) {
        $cur->{$p} = $flat->{$key};
      } else {
        $cur->{$p} = {} unless ref $cur->{$p} eq 'HASH' || ref $cur->{$p} eq 'ARRAY';
        $cur = $cur->{$p};
      }
    }
  }
  return \%out;
}

sub _resolve ($self, $pattern, $flat) {
  unless ($pattern =~ /\*/) {
    return ([$pattern, $flat->{$pattern}]) if exists $flat->{$pattern};
    my $alt = $pattern; $alt =~ s/\./\]\[/g;
    return ([$pattern, $flat->{$alt}]) if exists $flat->{$alt};
    return ([$pattern, undef]);
  }

  my @parts = split /\./, $pattern;

  my @keys = map { [ $_, [ $_ =~ /\G(?:^|\]\[?|\[)([^\[\]]+)/g ] ] } sort keys %$flat;

  my @results;

  my $walk;
  $walk = sub ($fixed_parts, $seg_idx) {
    if ($seg_idx == @parts) {
      my $concrete = join '.', @$fixed_parts;
      my ($real) = map { $_->[0] }
                   grep { join('.', @{ $_->[1] }) eq $concrete }
                   @keys;
      push @results, [$concrete, defined $real ? $flat->{$real} : undef];
      return;
    }

    my $part = $parts[$seg_idx];

    if ($part eq '*') {
      my %seen;
      for my $k (@keys) {
        my @kp = @{ $k->[1] };
        next unless @kp >= $seg_idx + 1;
        my $match = 1;
        for my $i (0 .. $seg_idx - 1) {
          my $want = $fixed_parts->[$i];
          if ($kp[$i] ne $want) { $match = 0; last; }
        }
        next unless $match;
        $seen{ $kp[$seg_idx] } = 1;
      }
      for my $val (sort keys %seen) {
        $walk->([@$fixed_parts, $val], $seg_idx + 1);
      }
    }
    else {
      $walk->([@$fixed_parts, $part], $seg_idx + 1);
    }
  };

  $walk->([], 0);
  return @results;
}

sub _message ($self, $field, $rule, $messages, $attrs, $args = []) {
  my $key = "$field.$rule";
  return $messages->{$key} if exists $messages->{$key};

  my $a0 = defined $args->[0] ? $args->[0] : '';
  my $a1 = defined $args->[1] ? $args->[1] : '';

  my %defaults = (
    required   => 'is required',
    integer    => 'must be an integer',
    numeric    => 'must be numeric',
    boolean    => 'must be true or false',
    email      => 'must be a valid email',
    url        => 'must be a valid URL',
    ip         => 'must be a valid IP address',
    uuid       => 'must be a valid UUID',
    alpha      => 'must contain only letters',
    alpha_num  => 'must contain only letters and numbers',
    alpha_dash => 'must contain only letters, numbers, dashes and underscores',
    min        => "must be at least $a0 characters",
    max        => "must be at most $a0 characters",
    between    => "must be between $a0 and $a1 characters",
    size       => "must be exactly $a0 characters",
    in         => 'is not in the allowed list',
    not_in     => 'is in the forbidden list',
    regex      => 'has an invalid format',
    confirmed  => 'confirmation does not match',
    same       => "must match $a0",
    different  => "must differ from $a0",
    date       => 'must be a valid date (YYYY-MM-DD)',
    array      => 'must be an array',
    json       => 'must be valid JSON',
    unique     => 'has already been taken',
    exists     => 'does not exist',
  );
  return $defaults{$rule} // "failed $rule";
}

1;

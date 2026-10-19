package Mojolicious::Plugin::FormRequest::Validator;
use Mojo::Base -base, -signatures;

use Mojolicious::Plugin::FormRequest::Rules;
use Mojolicious::Plugin::FormRequest::Db;
use Mojolicious::Plugin::FormRequest::Exception;

has 'c';
has 'request_class';
has 'inline_rules';
has 'inline_messages';
has 'inline_attributes';

sub validate ($self) {
  my $c     = $self->c;
  my $class = $self->request_class;
  my $req   = $class->new;

  my $inline = $self->inline_rules;

  unless ($inline || $req->authorize($c)) {
    return { ok => 0, status => 403, errors => { _authorization => 'Forbidden' } };
  }

  my $rules    = $self->inline_rules      // $req->rules($c)      // {};
  my $messages = $self->inline_messages   // $req->messages($c)   // {};
  my $attrs    = $self->inline_attributes // $req->attributes($c) // {};

  my $raw      = $self->_collect_input($c);
  my $prepared = $inline ? { %$raw } : $req->prepare_for_validation($c, { %$raw });
  my $flat     = $prepared // $raw;

  my $params = $self->_inflate($flat);
  $params = { %$flat, %$params };

  my $db  = Mojolicious::Plugin::FormRequest::Db->new(
    c        => $c,
    resolver => $c->app->config->{FormRequest}{db},
  );
  my $ctx = { c => $c, db => $db };

  my $stop_on_first = $inline ? 1 : $req->stop_on_first_failure($c);

  my %errors;
  my %validated;

  for my $pattern (keys %$rules) {
    my @targets = $self->_resolve($pattern, $flat);

    unless (@targets) {
      if ($pattern !~ /\*/ && !ref $rules->{$pattern} && $rules->{$pattern} =~ /\brequired\b/) {
        my $msg = $self->_message($pattern, 'required', $messages, $attrs);
        $msg = $self->_interpolate_message($msg, $pattern, undef, $attrs->{$pattern} // $pattern, []);
        $self->_push_error(\%errors, $pattern, $msg, $stop_on_first);
      }
      next;
    }

    for my $pair (@targets) {
      my ($field_name, $value) = @$pair;
      my $rule_str = $rules->{$pattern};

      next if !ref $rule_str && $rule_str =~ /\bsometimes\b/ && !defined $value;

      my @parsed    = $self->_parse_rules($rule_str);
      my $nullable  = grep { $_->{name} eq 'nullable' } @parsed;
      my $missing   = !defined $value || (ref $value ne 'ARRAY' && $value eq '');

      if ($nullable && $missing) {
        $validated{$field_name} = $value;
        next;
      }

      my $field_failed = 0;

      for my $r (@parsed) {
        my $name = $r->{name};
        my $args = $r->{args};
        next if $name eq 'nullable' || $name eq 'sometimes' || $name eq 'bail';

        if ($name eq 'required') {
          if ($missing) {
            my $tmpl = $self->_message($field_name, 'required', $messages, $attrs);
            my $msg  = $self->_interpolate_message(
              $tmpl, $field_name, $value, $attrs->{$field_name} // $field_name, []
            );
            $self->_push_error(\%errors, $field_name, $msg, $stop_on_first);
            $field_failed = 1;
            last;
          }
          next;
        }

        next if $missing && $name ne 'required_if'
                          && $name ne 'required_unless'
                          && $name ne 'required_with'
                          && $name ne 'required_without';

        if ($name eq 'confirmed') {
          my $confirm = $params->{"${field_name}_confirmation"} // '';
          unless ($confirm eq $value) {
            my $tmpl = $self->_message($field_name, 'confirmed', $messages, $attrs);
            my $msg  = $self->_interpolate_message(
              $tmpl, $field_name, $value, $attrs->{$field_name} // $field_name, []
            );
            $self->_push_error(\%errors, $field_name, $msg, $stop_on_first);
            $field_failed = 1;
            last;
          }
          next;
        }

        my $code;
        if ($name eq '__custom') {
          $code = $r->{code};
        }
        elsif ($name eq '__object') {
          my $obj = $r->{object};
          $code = sub ($value, $args, $params, $ctx) {
            return $obj->validate($value, $args, $params, $ctx);
          };
        }
        else {
          $code = Mojolicious::Plugin::FormRequest::Rules->get($name);
        }
        next unless $code;

        unless ($code->($value, $args, $params, $ctx)) {
          my $tmpl;
          if ($name eq '__object' && $r->{object}->can('message')) {
            $tmpl = $r->{object}->message;
          }
          else {
            $tmpl = $self->_message($field_name, $name, $messages, $attrs, $args);
          }
          my $msg  = $self->_interpolate_message(
            $tmpl, $field_name, $value, $attrs->{$field_name} // $field_name, $args
          );
          $self->_push_error(\%errors, $field_name, $msg, $stop_on_first);
          $field_failed = 1;
          last if $stop_on_first;
        }
      }

      $validated{$field_name} = $value unless $field_failed;
    }
  }

  unless ($inline) {
    my $after = $req->after_validation($c, \%errors, \%validated);
    if (ref $after eq 'HASH') { %errors = %$after; }
  }

  for my $k (keys %errors) {
    if (ref $errors{$k} eq 'ARRAY' && @{ $errors{$k} } == 1) {
      $errors{$k} = $errors{$k}[0];
    }
  }

  return { ok => 0, status => 422, errors => \%errors } if %errors;
  return { ok => 1, data => \%validated };
}

sub _collect_input ($self, $c) {
  my $params = $c->req->params;
  my $flat;
  if (ref($params) && eval { $params->can('to_hash') }) {
    $flat = $params->to_hash;
  }
  elsif (ref $params eq 'HASH') {
    $flat = { %$params };
  }
  else {
    $flat = {};
  }
  my $json = $c->req->json;
  if (ref $json eq 'HASH') {
    $flat = { %$flat, %$json };
  }
  return $flat;
}

sub _push_error ($self, $errors, $field, $msg, $stop_on_first) {
  if ($stop_on_first) {
    $errors->{$field} = $msg;
  }
  else {
    $errors->{$field} = [] unless ref $errors->{$field} eq 'ARRAY';
    push @{ $errors->{$field} }, $msg;
  }
}

sub validated ($self) {
  my $res = $self->validate;
  if ($res->{ok}) {
    return $res->{data};
  }
  die Mojolicious::Plugin::FormRequest::Exception->new(
    status => $res->{status},
    errors => $res->{errors},
  );
}

sub validate_or_fail ($self) {
  my $c   = $self->c;
  my $res = $self->validate;
  if ($res->{ok}) {
    return $res->{data};
  }
  my $status = $res->{status} // 422;
  if ($status == 403) {
    $c->render(json => { ok => 0, error => 'Forbidden' }, status => 403);
  }
  else {
    $c->render(json => { ok => 0, errors => $res->{errors} }, status => 422);
  }
  return undef;
}

sub _parse_rules ($self, $spec) {
  my @raw;
  if (ref $spec eq 'ARRAY') {
    @raw = @$spec;
  }
  elsif (ref $spec eq 'CODE' || (ref $spec && $spec->can('validate'))) {
    @raw = ($spec);
  }
  elsif (defined $spec) {
    push @raw, $self->_split_rule_string($spec);
  }

  my @out;
  for my $r (@raw) {
    if (ref $r eq 'CODE') {
      push @out, { code => $r, name => '__custom', args => [] };
      next;
    }
    if (ref $r && $r->can('validate')) {
      push @out, { object => $r, name => '__object', args => [] };
      next;
    }
    next unless defined $r && $r ne '';
    my ($name, $argstr) = split /:/, $r, 2;
    my @args = defined $argstr ? split /,/, $argstr : ();
    push @out, { name => $name, args => \@args };
  }
  return @out;
}

sub _split_rule_string ($self, $spec) {
  my @out;
  my $buf = '';
  my $in_regex = 0;
  for my $ch (split //, $spec) {
    if (!$in_regex && $buf =~ /(?:^|\|)regex:$/) { $in_regex = 1; }
    if ($in_regex) {
      $buf .= $ch;
      if ($ch eq '/' && $buf =~ m{regex:[^/]+/$}) { $in_regex = 0; }
      next;
    }
    if ($ch eq '|') { push @out, $buf; $buf = ''; next; }
    $buf .= $ch;
  }
  push @out, $buf if length $buf;
  return @out;
}

sub _interpolate_message ($self, $template, $field, $value, $attr, $args) {
  my $a0 = defined $args->[0] ? $args->[0] : '';
  my $a1 = defined $args->[1] ? $args->[1] : '';
  my %map = (
    ':attribute' => $attr,
    ':value'     => defined $value ? $value : '',
    ':min'       => $a0,
    ':max'       => $a1,
    ':other'     => $a0,
  );
  my $msg = $template;
  for my $k (keys %map) {
    my $v = defined $map{$k} ? $map{$k} : '';
    $msg =~ s/\Q$k\E/$v/g;
  }
  return $msg;
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
    required          => 'is required',
    integer           => 'must be an integer',
    numeric           => 'must be numeric',
    boolean           => 'must be true or false',
    email             => 'must be a valid email',
    url               => 'must be a valid URL',
    ip                => 'must be a valid IP address',
    uuid              => 'must be a valid UUID',
    alpha             => 'must contain only letters',
    alpha_num         => 'must contain only letters and numbers',
    alpha_dash        => 'must contain only letters, numbers, dashes and underscores',
    password          => 'must be a non-empty string',
    min               => "must be at least $a0 characters",
    max               => "must be at most $a0 characters",
    between           => "must be between $a0 and $a1 characters",
    size              => "must be exactly $a0 characters",
    in                => 'is not in the allowed list',
    not_in            => 'is in the forbidden list',
    regex             => 'has an invalid format',
    confirmed         => 'confirmation does not match',
    same              => "must match $a0",
    different         => "must differ from $a0",
    date              => 'must be a valid date (YYYY-MM-DD)',
    array             => 'must be an array',
    json              => 'must be valid JSON',
    unique            => 'has already been taken',
    exists            => 'does not exist',
    __custom          => 'is invalid',
    __object          => 'is invalid',
    distinct          => 'has a duplicate value',
    prohibited        => 'must be empty',
    required_if       => 'is required in this case',
    required_unless   => 'is required in this case',
    required_with     => 'is required when its companion field is present',
    required_without  => 'is required when its companion field is missing',
  );
  return $defaults{$rule} // "failed $rule";
}

1;

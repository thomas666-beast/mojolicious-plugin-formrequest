package Test::RuleClass;
use Mojo::Base -base, -signatures;

sub validate ($self, $value, $args, $params, $ctx) {
  return defined $value && length($value) % 2 == 0 ? 1 : 0;
}

1;

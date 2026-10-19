package Test::Task8Req;
use Mojo::Base 'Mojolicious::Plugin::FormRequest::Base', -signatures;
use lib 't/lib';
use Test::RuleClass;

sub authorize ($self, $c) { 1 }

sub rules ($self, $c) {
  return {
    tags         => ['required', 'distinct'],
    maybe_skip   => ['prohibited'],
    kind         => ['required'],
    email        => ['required_if:kind,email', 'email'],
    nickname     => ['required_unless:kind,email'],
    phone        => ['required_with:contact_pref'],
    even_length  => ['required', Test::RuleClass->new],
  };
}

1;

package Test::ArrayReq;
use Mojo::Base 'Mojolicious::Plugin::FormRequest::Base', -signatures;

sub authorize ($self, $c) { 1 }

sub rules ($self, $c) {
  return {
    email => ['required', 'email'],
    name  => ['required', 'string', 'min:3', 'max:20'],
    nick  => ['required', 'alpha_dash'],
    code  => ['required', 'regex:/^[A-Z]{3}-\d{3}$/'],
    custom_rule => [
      sub ($value, $args, $params, $ctx) {
        return $value eq 'magic' ? 1 : 0;
      },
    ],
  };
}

sub messages ($self, $c) {
  return {
    'email.required'       => ':attribute is mandatory',
    'name.min'             => ':attribute needs at least :min characters',
    'code.regex'           => ':attribute does not match the pattern',
    'custom_rule.__custom' => ':attribute is not magic',
  };
}

sub attributes ($self, $c) {
  return {
    email       => 'Email Address',
    name        => 'Full Name',
    code        => 'Promo Code',
    custom_rule => 'Secret Word',
  };
}

1;

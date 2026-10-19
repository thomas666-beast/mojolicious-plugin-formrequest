package Test::FullReq;
use Mojo::Base 'Mojolicious::Plugin::FormRequest::Base', -signatures;

sub authorize ($self, $c) { 1 }

sub rules ($self, $c) {
  return {
    username  => 'required|alpha_dash|min:3|max:20',
    age       => 'required|integer|between:18,99',
    email     => 'required|email',
    website   => 'nullable|url',
    role      => 'required|in:admin,user,guest',
    password  => 'required|min:8|confirmed',
    start_at  => 'required|date',
  };
}

1;

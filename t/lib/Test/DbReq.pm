package Test::DbReq;
use Mojo::Base 'Mojolicious::Plugin::FormRequest::Base', -signatures;

sub authorize ($self, $c) { 1 }

sub rules ($self, $c) {
  return {
    email    => 'required|email|unique:users,email',
    username => 'required|unique:users,username',
    role_id  => 'required|exists:roles,id',
  };
}

1;

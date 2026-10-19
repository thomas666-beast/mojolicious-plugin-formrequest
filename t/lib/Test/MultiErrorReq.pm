package Test::MultiErrorReq;
use Mojo::Base 'Mojolicious::Plugin::FormRequest::Base', -signatures;

sub authorize ($self, $c) { 1 }

sub stop_on_first_failure ($self, $c) { 0 }

sub rules ($self, $c) {
  return {
    name  => 'required|min:3|max:10|alpha',
    email => 'required|email',
  };
}

1;

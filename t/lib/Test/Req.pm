package Test::Req;
use Mojo::Base 'Mojolicious::Plugin::FormRequest::Base', -signatures;

sub authorize ($self, $c) { 1 }

sub rules ($self, $c) {
  return { name => 'required|string', email => 'required|email' };
}

1;

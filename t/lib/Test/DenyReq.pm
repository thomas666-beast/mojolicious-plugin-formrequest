package Test::DenyReq;
use Mojo::Base 'Mojolicious::Plugin::FormRequest::Base', -signatures;

sub authorize ($self, $c) { 0 }

sub rules ($self, $c) {
  return { name => 'required' };
}

1;

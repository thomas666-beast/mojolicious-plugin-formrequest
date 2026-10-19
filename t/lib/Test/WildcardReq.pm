package Test::WildcardReq;
use Mojo::Base 'Mojolicious::Plugin::FormRequest::Base', -signatures;

sub authorize ($self, $c) { 1 }

sub rules ($self, $c) {
  return {
    'items.*.name' => 'required|string',
    'items.*.qty'  => 'required|integer|min:1',
  };
}

1;

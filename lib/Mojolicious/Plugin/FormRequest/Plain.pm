package Mojolicious::Plugin::FormRequest::Plain;
use Mojo::Base -base, -signatures;

use Mojolicious::Plugin::FormRequest::Base;
use Mojolicious::Plugin::FormRequest::Validator;
use Mojolicious::Plugin::FormRequest::Exception;

has 'data';
has 'rules';
has 'messages';
has 'attributes';
has 'app';

sub make ($class, %args) {
  return $class->new(%args);
}

sub validate ($self) {
  my $c = $self->_fake_controller;
  my $v = Mojolicious::Plugin::FormRequest::Validator->new(
    c                 => $c,
    request_class     => 'Mojolicious::Plugin::FormRequest::Base',
    inline_rules      => $self->rules      // {},
    inline_messages   => $self->messages   // {},
    inline_attributes => $self->attributes // {},
  );
  return $v->validate;
}

sub validated ($self) {
  my $res = $self->validate;
  if ($res->{ok}) { return $res->{data} }
  die Mojolicious::Plugin::FormRequest::Exception->new(
    status => $res->{status},
    errors => $res->{errors},
  );
}

sub _fake_controller ($self) {
  my $data = $self->data // {};
  my $json = ref $data eq 'HASH' ? { %$data } : undef;
  my $req  = Mojolicious::Plugin::FormRequest::Plain::Req->new(
    params => { %$data },
    json   => $json,
  );
  my $app = $self->app // Mojolicious::Plugin::FormRequest::Plain::App->new(
    config => { FormRequest => {} },
  );
  return Mojolicious::Plugin::FormRequest::Plain::C->new(app => $app, req => $req);
}

package Mojolicious::Plugin::FormRequest::Plain::C;
use Mojo::Base -base;
has 'app';
has 'req';

package Mojolicious::Plugin::FormRequest::Plain::Req;
use Mojo::Base -base;
has 'params';
has 'json';

package Mojolicious::Plugin::FormRequest::Plain::App;
use Mojo::Base -base;
has 'config';

1;

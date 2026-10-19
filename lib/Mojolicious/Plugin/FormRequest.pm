package Mojolicious::Plugin::FormRequest;
use Mojo::Base 'Mojolicious::Plugin', -signatures;

use Mojolicious::Plugin::FormRequest::Validator;

sub register ($self, $app, $conf) {
  $app->config->{FormRequest}{db} = $conf->{db} if exists $conf->{db};

  $app->helper(form_request => sub ($c, $class) {
    return Mojolicious::Plugin::FormRequest::Validator->new(
      c             => $c,
      request_class => $class,
    );
  });
}

1;

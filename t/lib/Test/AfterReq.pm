package Test::AfterReq;
use Mojo::Base 'Mojolicious::Plugin::FormRequest::Base', -signatures;

sub authorize ($self, $c) { 1 }

sub rules ($self, $c) {
  return { name => 'required' };
}

sub after_validation ($self, $c, $errors, $validated) {
  my $errs = { %$errors };
  if (($validated->{name} // '') eq 'admin') {
    $errs->{name} = 'admin is reserved';
  }
  return $errs;
}

1;

package Test::PrepareReq;
use Mojo::Base 'Mojolicious::Plugin::FormRequest::Base', -signatures;

sub authorize ($self, $c) { 1 }

sub rules ($self, $c) {
  return {
    email => 'required|email',
    name  => 'required|min:3',
  };
}

sub prepare_for_validation ($self, $c, $data) {
  $data->{email} = lc($data->{email} // '');
  my $n = $data->{name} // '';
  $n =~ s/^\s+|\s+$//g;
  $n =~ s/\s+/ /g;
  $data->{name} = $n;
  return $data;
}

1;

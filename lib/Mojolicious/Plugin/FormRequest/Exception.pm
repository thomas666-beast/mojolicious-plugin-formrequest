package Mojolicious::Plugin::FormRequest::Exception;
use Mojo::Base -base, -signatures;
use overload '""' => sub ($self, @) { 'FormRequest validation failed' }, fallback => 1;

has 'status';
has 'errors';

sub new ($class, %args) {
  my $self = $class->SUPER::new(%args);
  $self->status($args{status} // 422);
  $self->errors($args{errors} // {});
  return $self;
}

sub to_hash ($self) {
  return {
    ok     => 0,
    status => $self->status,
    errors => $self->errors,
  };
}

1;

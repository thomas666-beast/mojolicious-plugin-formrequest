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

__END__

=head1 NAME

Mojolicious::Plugin::FormRequest::Exception - Typed exception thrown by validated()

=head1 DESCRIPTION

Carries C<status> and C<errors> from a failed validation.

=head1 TRUSTED

=over 4

=item to_hash

=back

=cut



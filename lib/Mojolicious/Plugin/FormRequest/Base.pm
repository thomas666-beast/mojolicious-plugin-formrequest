package Mojolicious::Plugin::FormRequest::Base;
use Mojo::Base -base, -signatures;

sub authorize ($self, $c) { 1 }

sub rules ($self, $c) { {} }

sub messages ($self, $c) { {} }

sub attributes ($self, $c) { {} }

# Override in subclass to mutate incoming data before rules run.
# Receives a hashref; return the (possibly new) hashref.
sub prepare_for_validation ($self, $c, $data) { $data }

# Override in subclass to add errors after rules run.
# Receives ($c, \%errors, \%validated); return the (possibly new) \%errors.
sub after_validation ($self, $c, $errors, $validated) { $errors }

# Override in subclass to turn off stop-on-first-failure for this request.
sub stop_on_first_failure ($self, $c) { 1 }

1;

__END__

=head1 NAME

Mojolicious::Plugin::FormRequest::Base - Base class for Form Request definitions

=head1 DESCRIPTION

Subclass this to declare validation rules.

=head1 TRUSTED

=over 4

=item after_validation

=item attributes

=item authorize

=item messages

=item prepare_for_validation

=item rules

=item stop_on_first_failure

=back

=cut



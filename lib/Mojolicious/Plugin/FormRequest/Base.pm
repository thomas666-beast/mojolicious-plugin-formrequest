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

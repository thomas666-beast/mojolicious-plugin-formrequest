package Mojolicious::Plugin::FormRequest::Base;
use Mojo::Base -base, -signatures;

# Subclasses override these.
sub authorize ($self, $c) { 1 }

sub rules ($self, $c) { {} }

sub messages ($self, $c) { {} }

sub attributes ($self, $c) { {} }

1;

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

__END__

=head1 NAME

Mojolicious::Plugin::FormRequest - Laravel-style form requests for Mojolicious

=head1 SYNOPSIS

  $app->plugin('FormRequest');
  $app->plugin('FormRequest', db => sub { $c->dbh });

  sub store ($self) {
    my $data = $self->form_request('MyApp::Requests::StoreUser')->validate_or_fail;
    return unless defined $data;
    $self->render(json => { created => $data });
  }

=head1 DESCRIPTION

Mojolicious::Plugin::FormRequest brings Laravel-style form request
validation to Mojolicious. You define validation rules in a
dedicated class (a "Form Request"), then run them from a controller with
a single call.

=head1 HELPERS

=head2 form_request

  my $data = $c->form_request('MyApp::Requests::StoreUser')->validate_or_fail;

Returns a L<Mojolicious::Plugin::FormRequest::Validator> bound to the
current controller and the given Form Request class.

=head1 FORM REQUEST CLASSES

A Form Request class inherits from L<Mojolicious::Plugin::FormRequest::Base>
and overrides C<rules>, and optionally C<authorize>, C<messages>,
C<attributes>, C<prepare_for_validation>, C<after_validation>, and
C<stop_on_first_failure>.

=head1 RULES

Standard rules: C<required>, C<nullable>, C<string>, C<integer>,
C<numeric>, C<boolean>, C<email>, C<url>, C<ip>, C<uuid>, C<alpha>,
C<alpha_num>, C<alpha_dash>, C<min>, C<max>, C<between>, C<size>, C<in>,
C<not_in>, C<regex>, C<confirmed>, C<same>, C<different>, C<date>,
C<array>, C<json>, C<distinct>, C<prohibited>, C<password>.

Conditional rules: C<required_if>, C<required_unless>, C<required_with>,
C<required_without>.

Database rules: C<unique:table,column[,except_id,id_column]>,
C<exists:table[,column]>.

Wildcards are supported: C<'items.*.name' =E<gt> 'required|string'>.

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Plugin::FormRequest::Base>,
L<Mojolicious::Plugin::FormRequest::Validator>,
L<Mojolicious::Plugin::FormRequest::Rule>,
L<Mojolicious::Plugin::FormRequest::Plain>.

=head1 AUTHOR

Thomas

=head1 LICENSE

Same as Perl.

=cut

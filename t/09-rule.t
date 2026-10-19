use Mojo::Base -strict, -signatures;
use Test::More;
use Mojolicious;
use DBI;
use Mojolicious::Plugin::FormRequest::Plain;
use Mojolicious::Plugin::FormRequest::Rule;

my $dbh = DBI->connect('dbi:SQLite:dbname=:memory:', '', '', { RaiseError => 1 });
$dbh->do('CREATE TABLE users (id INTEGER PRIMARY KEY, email TEXT UNIQUE)');
$dbh->do('CREATE TABLE roles (id INTEGER PRIMARY KEY, name TEXT)');
$dbh->do("INSERT INTO users (id, email) VALUES (1, 'taken\@example.com')");
$dbh->do("INSERT INTO roles (id, name) VALUES (1, 'admin')");

sub make_app {
  my $app = Mojolicious->new;
  $app->plugin('FormRequest', db => sub { $dbh });
  return $app;
}

{
  my $v = Mojolicious::Plugin::FormRequest::Plain->make(
    app   => make_app(),
    data  => { email => 'new@example.com' },
    rules => { email => ['required', Mojolicious::Plugin::FormRequest::Rule->unique('users', 'email')] },
  );
  my $res = $v->validate;
  ok $res->{ok}, 'Rule::unique passes for new email';
}

{
  my $v = Mojolicious::Plugin::FormRequest::Plain->make(
    app   => make_app(),
    data  => { email => 'taken@example.com' },
    rules => { email => ['required', Mojolicious::Plugin::FormRequest::Rule->unique('users', 'email')] },
  );
  my $res = $v->validate;
  ok !$res->{ok}, 'Rule::unique fails for taken email';
  like $res->{errors}{email}, qr/taken|already/i, 'error mentions taken';
}

{
  my $v = Mojolicious::Plugin::FormRequest::Plain->make(
    app   => make_app(),
    data  => { role_id => 1 },
    rules => { role_id => ['required', Mojolicious::Plugin::FormRequest::Rule->exists('roles', 'id')] },
  );
  my $res = $v->validate;
  ok $res->{ok}, 'Rule::exists passes for existing role';
}

{
  my $v = Mojolicious::Plugin::FormRequest::Plain->make(
    app   => make_app(),
    data  => { role_id => 99 },
    rules => { role_id => ['required', Mojolicious::Plugin::FormRequest::Rule->exists('roles', 'id')] },
  );
  my $res = $v->validate;
  ok !$res->{ok}, 'Rule::exists fails for missing role';
}

done_testing;

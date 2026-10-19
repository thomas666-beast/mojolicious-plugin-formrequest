use Mojo::Base -strict, -signatures;
use Test::More;
use Test::Mojo;
use Mojolicious;
use DBI;

use lib 't/lib';
use Test::DbReq;

my $dbh = DBI->connect('dbi:SQLite:dbname=:memory:', '', '', { RaiseError => 1 });
$dbh->do('CREATE TABLE users (id INTEGER PRIMARY KEY, email TEXT UNIQUE, username TEXT UNIQUE)');
$dbh->do('CREATE TABLE roles (id INTEGER PRIMARY KEY, name TEXT)');
$dbh->do("INSERT INTO users (id, email, username) VALUES (1, 'taken\@example.com', 'taken')");
$dbh->do("INSERT INTO roles (id, name) VALUES (1, 'admin'), (2, 'user')");

my $app = Mojolicious->new;
$app->plugin('FormRequest', db => sub { $dbh });
$app->routes->post('/check' => sub ($c) {
  my $res = $c->form_request('Test::DbReq')->validate;
  return $c->render(json => { ok => 0, errors => $res->{errors} }, status => $res->{status})
    unless $res->{ok};
  return $c->render(json => { ok => 1, data => $res->{data} });
});

my $t = Test::Mojo->new($app);

# --- 1. all valid ---
$t->post_ok('/check' => form => {
  email    => 'new@example.com',
  username => 'newuser',
  role_id  => 1,
})->status_is(200)->json_is('/ok' => 1);

# --- 2. email already taken (unique fails) ---
$t->post_ok('/check' => form => {
  email    => 'taken@example.com',
  username => 'newuser',
  role_id  => 1,
})->status_is(422)->json_like('/errors/email' => qr/taken|already|unique/i);

# --- 3. role_id does not exist (exists fails) ---
$t->post_ok('/check' => form => {
  email    => 'new@example.com',
  username => 'newuser',
  role_id  => 99,
})->status_is(422)->json_like('/errors/role_id' => qr/exists|not|does not/i);

done_testing;

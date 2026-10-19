use Mojo::Base -strict, -signatures;
use Test::More;
use Test::Mojo;
use Mojolicious;

use lib 't/lib';
use Test::Task8Req;

my $app = Mojolicious->new;
$app->plugin('FormRequest');
$app->routes->post('/check' => sub ($c) {
  my $res = $c->form_request('Test::Task8Req')->validate;
  return $c->render(json => { ok => 0, errors => $res->{errors} }, status => $res->{status})
    unless $res->{ok};
  return $c->render(json => { ok => 1, data => $res->{data} });
});

my $t = Test::Mojo->new($app);

sub check_ok ($label, $payload) {
  $t->post_ok('/check' => form => $payload);
  diag "$label body: " . $t->tx->res->body unless $t->tx->res->code == 200;
  $t->status_is(200)->json_is('/ok' => 1);
}

# --- happy path ---
check_ok('happy path', {
  tags         => 'a,b,c',
  kind         => 'email',
  email        => 'a@b.co',
  nickname     => 'alice',
  contact_pref => 'email',
  phone        => '123',
  even_length  => 'abcd',
});

# --- prohibited fires ---
$t->post_ok('/check' => form => {
  tags         => 'a,b',
  kind         => 'email',
  email        => 'a@b.co',
  nickname     => 'alice',
  contact_pref => 'email',
  phone        => '123',
  even_length  => 'abcd',
  maybe_skip   => 'something',
})->status_is(422)->json_like('/errors/maybe_skip' => qr/empty/);

# --- required_if fires ---
$t->post_ok('/check' => form => {
  tags         => 'a,b',
  kind         => 'email',
  nickname     => 'alice',
  contact_pref => 'email',
  phone        => '123',
  even_length  => 'abcd',
});
diag 'required_if body: ' . $t->tx->res->body unless $t->tx->res->code == 422;
$t->status_is(422)->json_like('/errors/email' => qr/required/);

# --- required_unless happy path ---
check_ok('required_unless happy', {
  tags         => 'a,b',
  kind         => 'email',
  email        => 'a@b.co',
  contact_pref => 'email',
  phone        => '123',
  even_length  => 'abcd',
});

# --- required_unless fires ---
$t->post_ok('/check' => form => {
  tags         => 'a,b',
  kind         => 'phone',
  contact_pref => 'email',
  phone        => '123',
  even_length  => 'abcd',
});
diag 'required_unless fire body: ' . $t->tx->res->body unless $t->tx->res->code == 422;
$t->status_is(422)->json_like('/errors/nickname' => qr/required/);

# --- required_with fires ---
$t->post_ok('/check' => form => {
  tags         => 'a,b',
  kind         => 'email',
  email        => 'a@b.co',
  nickname     => 'alice',
  contact_pref => 'email',
  even_length  => 'abcd',
});
diag 'required_with body: ' . $t->tx->res->body unless $t->tx->res->code == 422;
$t->status_is(422)->json_like('/errors/phone' => qr/required/);

# --- custom rule object fails ---
$t->post_ok('/check' => form => {
  tags         => 'a,b',
  kind         => 'email',
  email        => 'a@b.co',
  nickname     => 'alice',
  contact_pref => 'email',
  phone        => '123',
  even_length  => 'abc',
})->status_is(422)->json_like('/errors/even_length' => qr/invalid/);

# --- distinct via JSON ---
$t->post_ok('/check' => json => {
  tags         => ['a', 'b', 'c'],
  kind         => 'email',
  email        => 'a@b.co',
  nickname     => 'alice',
  contact_pref => 'email',
  phone        => '123',
  even_length  => 'abcd',
});
diag 'json happy body: ' . $t->tx->res->body unless $t->tx->res->code == 200;
$t->status_is(200)->json_is('/ok' => 1);

$t->post_ok('/check' => json => {
  tags         => ['a', 'b', 'a'],
  kind         => 'email',
  email        => 'a@b.co',
  nickname     => 'alice',
  contact_pref => 'email',
  phone        => '123',
  even_length  => 'abcd',
});
diag 'json dup body: ' . $t->tx->res->body unless $t->tx->res->code == 422;
$t->status_is(422)->json_like('/errors/tags' => qr/duplicate/);

done_testing;

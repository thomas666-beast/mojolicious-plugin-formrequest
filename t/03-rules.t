use Mojo::Base -strict, -signatures;
use Test::More;
use Test::Mojo;
use Mojolicious;

use lib 't/lib';
use Test::FullReq;
use Test::WildcardReq;

sub build_app ($req_class) {
  my $app = Mojolicious->new;
  $app->plugin('FormRequest');
  $app->routes->post('/check' => sub ($c) {
    my $res = $c->form_request($req_class)->validate;
    return $c->render(json => { ok => 0, errors => $res->{errors} }, status => $res->{status})
      unless $res->{ok};
    return $c->render(json => { ok => 1, data => $res->{data} });
  });
  return $app;
}

sub dump_if_not_ok ($t, $label) {
  my $tx = $t->tx;
  return if $tx->res->code == 200;
  diag "$label => " . $tx->res->body;
}

# --- FullReq: happy path ---
{
  my $t = Test::Mojo->new(build_app('Test::FullReq'));
  $t->post_ok('/check' => form => {
    username => 'alice_01',
    age      => 25,
    email    => 'alice@example.com',
    website  => 'https://example.com',
    role     => 'admin',
    password => 'secret123',
    password_confirmation => 'secret123',
    start_at => '2026-10-19',
  });
  dump_if_not_ok($t, 'FullReq happy path');
  $t->status_is(200)
    ->json_is('/ok' => 1)
    ->json_is('/data/username' => 'alice_01')
    ->json_is('/data/role' => 'admin');
}

# --- nullable website omitted ---
{
  my $t = Test::Mojo->new(build_app('Test::FullReq'));
  $t->post_ok('/check' => form => {
    username => 'alice_01',
    age      => 25,
    email    => 'alice@example.com',
    role     => 'user',
    password => 'secret123',
    password_confirmation => 'secret123',
    start_at => '2026-10-19',
  });
  dump_if_not_ok($t, 'FullReq nullable omitted');
  $t->status_is(200)
    ->json_is('/ok' => 1);
}

# --- bad role ---
{
  my $t = Test::Mojo->new(build_app('Test::FullReq'));
  $t->post_ok('/check' => form => {
    username => 'alice_01',
    age      => 25,
    email    => 'alice@example.com',
    role     => 'superuser',
    password => 'secret123',
    password_confirmation => 'secret123',
    start_at => '2026-10-19',
  })
    ->status_is(422)
    ->json_like('/errors/role' => qr/allowed/);
}

# --- password confirmation mismatch ---
{
  my $t = Test::Mojo->new(build_app('Test::FullReq'));
  $t->post_ok('/check' => form => {
    username => 'alice_01',
    age      => 25,
    email    => 'alice@example.com',
    role     => 'user',
    password => 'secret123',
    password_confirmation => 'different',
    start_at => '2026-10-19',
  })
    ->status_is(422)
    ->json_like('/errors/password' => qr/confirmation/);
}

# --- age out of range ---
{
  my $t = Test::Mojo->new(build_app('Test::FullReq'));
  $t->post_ok('/check' => form => {
    username => 'alice_01',
    age      => 15,
    email    => 'alice@example.com',
    role     => 'user',
    password => 'secret123',
    password_confirmation => 'secret123',
    start_at => '2026-10-19',
  })
    ->status_is(422)
    ->json_like('/errors/age' => qr/between/);
}

# --- username too short ---
{
  my $t = Test::Mojo->new(build_app('Test::FullReq'));
  $t->post_ok('/check' => form => {
    username => 'al',
    age      => 25,
    email    => 'alice@example.com',
    role     => 'user',
    password => 'secret123',
    password_confirmation => 'secret123',
    start_at => '2026-10-19',
  })
    ->status_is(422)
    ->json_like('/errors/username' => qr/at least 3/);
}

# --- WildcardReq: happy path with array ---
{
  my $t = Test::Mojo->new(build_app('Test::WildcardReq'));
  $t->post_ok('/check' => form => {
    'items[0][name]' => 'apple',
    'items[0][qty]'  => 3,
    'items[1][name]' => 'banana',
    'items[1][qty]'  => 5,
  });
  dump_if_not_ok($t, 'WildcardReq happy path');
  $t->status_is(200)
    ->json_is('/ok' => 1);
}

# --- WildcardReq: one item missing name ---
{
  my $t = Test::Mojo->new(build_app('Test::WildcardReq'));
  $t->post_ok('/check' => form => {
    'items[0][name]' => 'apple',
    'items[0][qty]'  => 3,
    'items[1][qty]'  => 5,
  });
  dump_if_not_ok($t, 'WildcardReq missing name');
  $t->status_is(422)
    ->json_like('/errors/items.1.name' => qr/required/);
}

done_testing;

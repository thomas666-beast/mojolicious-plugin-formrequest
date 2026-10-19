use Mojo::Base -strict, -signatures;
use Test::More;
use Test::Mojo;
use Mojolicious;

use lib 't/lib';
use Test::ArrayReq;

my $app = Mojolicious->new;
$app->plugin('FormRequest');
$app->routes->post('/check' => sub ($c) {
  my $res = $c->form_request('Test::ArrayReq')->validate;
  return $c->render(json => { ok => 0, errors => $res->{errors} }, status => $res->{status})
    unless $res->{ok};
  return $c->render(json => { ok => 1, data => $res->{data} });
});

my $t = Test::Mojo->new($app);

$t->post_ok('/check' => form => {
  email       => 'a@b.co',
  name        => 'Alice',
  nick        => 'alice_01',
  code        => 'ABC-123',
  custom_rule => 'magic',
})->status_is(200)->json_is('/ok' => 1);

$t->post_ok('/check' => form => {
  name        => 'Alice',
  nick        => 'alice_01',
  code        => 'ABC-123',
  custom_rule => 'magic',
})->status_is(422)->json_like('/errors/email' => qr/Email Address is mandatory/);

$t->post_ok('/check' => form => {
  email       => 'a@b.co',
  name        => 'Al',
  nick        => 'alice_01',
  code        => 'ABC-123',
  custom_rule => 'magic',
})->status_is(422)->json_like('/errors/name' => qr/Full Name needs at least 3 characters/);

$t->post_ok('/check' => form => {
  email       => 'a@b.co',
  name        => 'Alice',
  nick        => 'alice_01',
  code        => 'bad',
  custom_rule => 'magic',
})->status_is(422)->json_like('/errors/code' => qr/Promo Code does not match/);

$t->post_ok('/check' => form => {
  email       => 'a@b.co',
  name        => 'Alice',
  nick        => 'alice_01',
  code        => 'ABC-123',
  custom_rule => 'ordinary',
})->status_is(422)->json_like('/errors/custom_rule' => qr/Secret Word is not magic/);

done_testing;

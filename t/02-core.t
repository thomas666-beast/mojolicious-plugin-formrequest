use Mojo::Base -strict, -signatures;
use Test::More;
use Test::Mojo;
use Mojolicious;

use lib 't/lib';
use Test::Req;
use Test::DenyReq;

# --- 1. plugin registers helper ---
{
  my $app = Mojolicious->new;
  $app->plugin('FormRequest');
  my $c = $app->build_controller;
  ok exists $c->app->renderer->helpers->{form_request}, 'helper registered';
}

# --- 2. passing validation ---
{
  my $app = Mojolicious->new;
  $app->plugin('FormRequest');

  $app->routes->post('/store' => sub ($c) {
    my $res = $c->form_request('Test::Req')->validate;
    return $c->render(json => { ok => 0, errors => $res->{errors} }, status => $res->{status})
      unless $res->{ok};
    return $c->render(json => { ok => 1, data => $res->{data} });
  });

  my $t = Test::Mojo->new($app);
  $t->post_ok('/store' => form => { name => 'Alice', email => 'alice@example.com' })
    ->status_is(200)
    ->json_is('/ok'         => 1)
    ->json_is('/data/name'  => 'Alice')
    ->json_is('/data/email' => 'alice@example.com');
}

# --- 3. missing required field ---
{
  my $app = Mojolicious->new;
  $app->plugin('FormRequest');

  $app->routes->post('/store' => sub ($c) {
    my $res = $c->form_request('Test::Req')->validate;
    return $c->render(json => { ok => 0, errors => $res->{errors} }, status => $res->{status})
      unless $res->{ok};
    return $c->render(json => { ok => 1, data => $res->{data} });
  });

  my $t = Test::Mojo->new($app);
  $t->post_ok('/store' => form => { email => 'alice@example.com' })
    ->status_is(422)
    ->json_is('/ok' => 0)
    ->json_like('/errors/name' => qr/required/);
}

# --- 4. email fails ---
{
  my $app = Mojolicious->new;
  $app->plugin('FormRequest');

  $app->routes->post('/store' => sub ($c) {
    my $res = $c->form_request('Test::Req')->validate;
    return $c->render(json => { ok => 0, errors => $res->{errors} }, status => $res->{status})
      unless $res->{ok};
    return $c->render(json => { ok => 1, data => $res->{data} });
  });

  my $t = Test::Mojo->new($app);
  $t->post_ok('/store' => form => { name => 'Alice', email => 'nope' })
    ->status_is(422)
    ->json_like('/errors/email' => qr/valid email/);
}

# --- 5. authorize false => 403 ---
{
  my $app = Mojolicious->new;
  $app->plugin('FormRequest');

  $app->routes->post('/store' => sub ($c) {
    my $res = $c->form_request('Test::DenyReq')->validate;
    return $c->render(json => { ok => 0, errors => $res->{errors} }, status => $res->{status})
      unless $res->{ok};
    return $c->render(json => { ok => 1, data => $res->{data} });
  });

  my $t = Test::Mojo->new($app);
  $t->post_ok('/store' => form => { name => 'Alice' })
    ->status_is(403)
    ->json_is('/ok' => 0);
}

done_testing;

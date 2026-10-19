use Mojo::Base -strict, -signatures;
use Test::More;
use Test::Mojo;
use Mojolicious;

use lib 't/lib';
use Test::PrepareReq;
use Test::AfterReq;
use Test::MultiErrorReq;

sub make_app ($req_class) {
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

# --- prepareForValidation lowercases email ---
{
  my $t = Test::Mojo->new(make_app('Test::PrepareReq'));
  $t->post_ok('/check' => form => { email => 'Alice@Example.COM', name => '  Alice  ' })
    ->status_is(200)
    ->json_is('/data/email' => 'alice@example.com')
    ->json_is('/data/name'  => 'Alice');
}

# --- after_validation adds an error ---
{
  my $t = Test::Mojo->new(make_app('Test::AfterReq'));
  $t->post_ok('/check' => form => { name => 'admin' })
    ->status_is(422)
    ->json_like('/errors/name' => qr/admin is reserved/);
}

# --- after_validation passes through when no extra error ---
{
  my $t = Test::Mojo->new(make_app('Test::AfterReq'));
  $t->post_ok('/check' => form => { name => 'alice' })
    ->status_is(200)
    ->json_is('/ok' => 1);
}

# --- stop_on_first_failure(0) collects multiple errors on one field ---
{
  my $t = Test::Mojo->new(make_app('Test::MultiErrorReq'));
  $t->post_ok('/check' => form => { name => '1', email => 'not-an-email' })
    ->status_is(422);

  my $body = $t->tx->res->json;
  ok ref $body->{errors}{name} eq 'ARRAY', 'name errors are an array';
  ok scalar @{ $body->{errors}{name} } >= 2, 'name collected multiple errors';
  ok ref $body->{errors}{email} eq 'ARRAY' || defined $body->{errors}{email},
     'email error present';
}

# --- password rule ---
{
  my $app = Mojolicious->new;
  $app->plugin('FormRequest');
  $app->routes->post('/pw' => sub ($c) {
    my $res = $c->form_request('Test::PrepareReq')->validate;
    return $c->render(json => { ok => 0, errors => $res->{errors} }, status => $res->{status})
      unless $res->{ok};
    return $c->render(json => { ok => 1 });
  });

  my $t = Test::Mojo->new($app);
  $t->post_ok('/pw' => form => { email => 'a@b.co', name => 'abc' })
    ->status_is(200);
}

done_testing;

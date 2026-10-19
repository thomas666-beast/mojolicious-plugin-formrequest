use Mojo::Base -strict, -signatures;
use Test::More;
use Test::Mojo;
use Mojolicious;

use lib 't/lib';
use Test::OrFailReq;
use Test::DenyOrFailReq;

# --- validate_or_fail: happy path returns plain data hashref ---
{
  my $app = Mojolicious->new;
  $app->plugin('FormRequest');
  $app->routes->post('/ok' => sub ($c) {
    my $data = $c->form_request('Test::OrFailReq')->validate_or_fail;
    return unless defined $data;
    return $c->render(json => { got => $data });
  });

  my $t = Test::Mojo->new($app);
  $t->post_ok('/ok' => form => { name => 'Alice', email => 'a@b.co' })
    ->status_is(200)
    ->json_is('/got/name'  => 'Alice')
    ->json_is('/got/email' => 'a@b.co');
}

# --- validate_or_fail: failure renders 422 and returns undef ---
{
  my $app = Mojolicious->new;
  $app->plugin('FormRequest');
  $app->routes->post('/ok' => sub ($c) {
    my $data = $c->form_request('Test::OrFailReq')->validate_or_fail;
    return unless defined $data;
    return $c->render(json => { got => $data });
  });

  my $t = Test::Mojo->new($app);
  $t->post_ok('/ok' => form => { email => 'a@b.co' })
    ->status_is(422)
    ->json_is('/ok' => 0)
    ->json_like('/errors/name' => qr/required/);
}

# --- validate_or_fail: authorization failure renders 403 ---
{
  my $app = Mojolicious->new;
  $app->plugin('FormRequest');
  $app->routes->post('/ok' => sub ($c) {
    my $data = $c->form_request('Test::DenyOrFailReq')->validate_or_fail;
    return unless defined $data;
    return $c->render(json => { got => $data });
  });

  my $t = Test::Mojo->new($app);
  $t->post_ok('/ok' => form => { name => 'Alice' })
    ->status_is(403)
    ->json_is('/ok' => 0);
}

# --- validated: happy path returns plain hashref ---
{
  my $app = Mojolicious->new;
  $app->plugin('FormRequest');
  $app->routes->post('/v' => sub ($c) {
    my $data = $c->form_request('Test::OrFailReq')->validated;
    return $c->render(json => { got => $data });
  });

  my $t = Test::Mojo->new($app);
  $t->post_ok('/v' => form => { name => 'Alice', email => 'a@b.co' })
    ->status_is(200)
    ->json_is('/got/name' => 'Alice');
}

# --- validated: failure throws, route's eval catches it ---
{
  my $app = Mojolicious->new;
  $app->plugin('FormRequest');
  $app->routes->post('/v' => sub ($c) {
    my $data = eval { $c->form_request('Test::OrFailReq')->validated };
    if (my $e = $@) {
      if (ref $e && $e->can('to_hash')) {
        return $c->render(json => $e->to_hash, status => $e->status);
      }
      return $c->render(json => { ok => 0, error => "$e" }, status => 500);
    }
    return $c->render(json => { got => $data });
  });

  my $t = Test::Mojo->new($app);
  $t->post_ok('/v' => form => { email => 'a@b.co' })
    ->status_is(422)
    ->json_is('/ok' => 0)
    ->json_like('/errors/name' => qr/required/);
}

done_testing;

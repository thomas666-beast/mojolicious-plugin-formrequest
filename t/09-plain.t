use Mojo::Base -strict, -signatures;
use Test::More;
use Mojolicious::Plugin::FormRequest::Plain;
use Mojolicious::Plugin::FormRequest::Rule;

use lib 't/lib';

{
  my $v = Mojolicious::Plugin::FormRequest::Plain->make(
    data  => { name => 'Alice', email => 'a@b.co' },
    rules => { name => 'required|min:3', email => 'required|email' },
  );
  my $res = $v->validate;
  ok $res->{ok}, 'plain happy path ok';
  is $res->{data}{name}, 'Alice', 'name preserved';
}

{
  my $v = Mojolicious::Plugin::FormRequest::Plain->make(
    data  => { email => 'a@b.co' },
    rules => { name => 'required', email => 'required|email' },
  );
  my $res = $v->validate;
  ok !$res->{ok}, 'plain failure';
  like $res->{errors}{name}, qr/required/, 'name required';
}

{
  my $v = Mojolicious::Plugin::FormRequest::Plain->make(
    data  => { email => 'not-an-email' },
    rules => { email => 'required|email' },
  );
  my $ok = eval { $v->validated; 1 };
  ok !$ok, 'validated throws on failure';
  like "$@", qr/FormRequest validation failed/, 'exception message';
}

{
  my $rule = Mojolicious::Plugin::FormRequest::Rule->in([qw(admin user)]);
  ok $rule->validate('admin', [], {}, {}), 'Rule::in pass';
  ok !$rule->validate('guest', [], {}, {}), 'Rule::in fail';
}

{
  my $rule = Mojolicious::Plugin::FormRequest::Rule->not_in([qw(banned)]);
  ok $rule->validate('ok', [], {}, {}), 'Rule::not_in pass';
  ok !$rule->validate('banned', [], {}, {}), 'Rule::not_in fail';
}

{
  my $v = Mojolicious::Plugin::FormRequest::Plain->make(
    data  => { role => 'guest' },
    rules => { role => ['required', Mojolicious::Plugin::FormRequest::Rule->in([qw(admin user)])] },
  );
  my $res = $v->validate;
  ok !$res->{ok}, 'Rule::in object fails';
  like $res->{errors}{role}, qr/allowed|invalid/i, 'error message mentions failure';
}

done_testing;

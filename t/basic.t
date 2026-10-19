use Mojo::Base -strict;
use Test::More;
use Test::Mojo;

use Mojolicious::Plugin::FormRequest;

my $t = Test::Mojo->new('Mojolicious');
$t->app->plugin('FormRequest');
ok 1;
done_testing;

use strict;
use warnings;
use Test::More;

eval "use Test::Pod::Coverage 1.08";
plan skip_all => 'Test::Pod::Coverage 1.08 required' if $@;

eval "use Pod::Coverage::TrustPod";
plan skip_all => 'Pod::Coverage::TrustPod required' if $@;

all_pod_coverage_ok({ trustme => [qr/^(new|register)$/] });

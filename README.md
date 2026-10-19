# Mojolicious::Plugin::FormRequest

Laravel-style form request validation for Mojolicious.

## Synopsis

```perl
# In your app
$app->plugin('FormRequest');

# In a controller
sub store ($self) {
  my $data = $self->form_request('MyApp::Requests::StoreUser')->validate_or_fail;
  return unless defined $data;
  $self->render(json => { created => $data });
}
```

```perl
# In lib/MyApp/Requests/StoreUser.pm
package MyApp::Requests::StoreUser;
use Mojo::Base 'Mojolicious::Plugin::FormRequest::Base', -signatures;

sub rules ($self, $c) {
  return {
    name  => 'required|min:3|max:50',
    email => 'required|email|unique:users,email',
    age   => 'nullable|integer|between:18,99',
  };
}

1;
```

## What it supports

### Standard rules

| Rule | Notes |
|---|---|
| `required` | Field must be present and non-empty |
| `nullable` | Field may be absent or empty |
| `string` | Value must not be a reference |
| `integer` | Value must be an integer |
| `numeric` | Value must be numeric |
| `boolean` | Value must be `0`, `1`, `true`, or `false` |
| `email` | Value must look like an email address |
| `url` | Value must start with `http://` or `https://` |
| `ip` | Value must look like an IPv4 address |
| `uuid` | Value must be a UUID |
| `alpha` | Letters only |
| `alpha_num` | Letters and digits only |
| `alpha_dash` | Letters, digits, `_`, `-` only |
| `min:N` | Numeric value >= N, or string length >= N |
| `max:N` | Numeric value <= N, or string length <= N |
| `between:lo,hi` | Numeric or length between lo and hi |
| `size:N` | Numeric value or string length exactly N |
| `in:a,b,c` | Value must be one of the list |
| `not_in:a,b,c` | Value must not be in the list |
| `regex:/pattern/` | Value must match the pattern |
| `confirmed` | Must equal `<field>_confirmation` |
| `same:other` | Must equal the other field |
| `different:other` | Must differ from the other field |
| `date` | Must be `YYYY-MM-DD` |
| `array` | Must be an arrayref |
| `json` | Must be valid JSON |
| `distinct` | Array must have no duplicate values |
| `prohibited` | Field must be absent or empty |
| `password` | Non-empty string (Laravel alias) |

### Conditional rules

| Rule | Notes |
|---|---|
| `required_if:other,value` | Required when `other` equals `value` |
| `required_unless:other,value` | Required unless `other` equals `value` |
| `required_with:other` | Required when `other` is present |
| `required_without:other` | Required when `other` is absent |

### Database rules

| Rule | Notes |
|---|---|
| `unique:table,column[,except_id,id_column]` | No other row may have this value |
| `exists:table[,column]` | A row with this value must exist |

Both rules use a configurable resolver:

```perl
# DBIx::Class: nothing to configure if your app has $app->schema
$app->plugin('FormRequest');

# Raw DBI
$app->plugin('FormRequest', db => sub { $c->dbh });
```

### Wildcards

```perl
sub rules ($self, $c) {
  return {
    'items'        => 'required|array',
    'items.*.name' => 'required|string',
    'items.*.qty'  => 'required|integer|min:1',
  };
}
```

## Form Request class hooks

```perl
package MyApp::Requests::StoreUser;
use Mojo::Base 'Mojolicious::Plugin::FormRequest::Base', -signatures;

sub authorize ($self, $c) { $c->is_user_authenticated }

sub rules ($self, $c) {
  return { name => 'required', email => 'required|email' };
}

sub messages ($self, $c) {
  return { 'name.required' => ':attribute is mandatory' };
}

sub attributes ($self, $c) {
  return { name => 'Full Name' };
}

sub prepare_for_validation ($self, $c, $data) {
  $data->{email} = lc($data->{email} // '');
  return $data;
}

sub after_validation ($self, $c, $errors, $validated) {
  $errors->{name} = 'is reserved' if ($validated->{name} // '') eq 'admin';
  return $errors;
}

sub stop_on_first_failure ($self, $c) { 0 }

1;
```

## Controller API

| Method | Behaviour |
|---|---|
| `->validate` | Returns `{ ok => 1, data => \%validated }` or `{ ok => 0, status => 422, errors => \%errors }` |
| `->validated` | Returns `\%validated` on success; throws `Mojolicious::Plugin::FormRequest::Exception` on failure |
| `->validate_or_fail` | Returns `\%validated` on success; renders 422 (or 403) and returns `undef` on failure |

One-liner controller:

```perl
sub store ($self) {
  my $data = $self->form_request('MyApp::Requests::StoreUser')->validate_or_fail;
  return unless defined $data;
  $self->render(json => { created => $data });
}
```

## Validating without a controller

```perl
use Mojolicious::Plugin::FormRequest::Plain;

my $v = Mojolicious::Plugin::FormRequest::Plain->make(
  data  => { name => 'Alice', email => 'a@b.co' },
  rules => { name => 'required|min:3', email => 'required|email' },
);
my $res = $v->validate;
```

## Fluent rule constructors

```perl
use Mojolicious::Plugin::FormRequest::Rule;

my $role    = Mojolicious::Plugin::FormRequest::Rule->in([qw(admin user guest)]);
my $email   = Mojolicious::Plugin::FormRequest::Rule->unique('users', 'email')->ignore($user_id);
my $role_id = Mojolicious::Plugin::FormRequest::Rule->exists('roles', 'id');

my $v = Mojolicious::Plugin::FormRequest::Plain->make(
  data  => { role => 'admin', email => 'a@b.co', role_id => 1 },
  rules => { role => ['required', $role], email => ['required', $email], role_id => ['required', $role_id] },
);
```

## Installation

From CPAN (once released):

```
cpanm Mojolicious::Plugin::FormRequest
```

From source:

```
git clone https://github.com/thomas666-beast/mojolicious-plugin-formrequest.git
cd mojolicious-plugin-formrequest
cpanm --installdeps .
prove -lv t
```

## Requirements

- Perl 5.20 or newer
- Mojolicious 9.0 or newer
- DBI (only needed if you use `unique` or `exists`)

Test dependencies: `Test::More`, `Test::Mojo`, `DBD::SQLite`, `Test::Pod`, `Test::Pod::Coverage`, `Pod::Coverage::TrustPod`.

## Author

Thomas — https://github.com/thomas666-beast

## License

Same as Perl.

## See also

- Mojolicious: https://mojolicious.org
- Mojolicious::Plugin::FormRequest::Base
- Mojolicious::Plugin::FormRequest::Validator
- Mojolicious::Plugin::FormRequest::Rule
- Mojolicious::Plugin::FormRequest::Plain
- Laravel Form Requests: https://laravel.com/docs/validation#form-request-validation

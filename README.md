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

## Standard rules

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
| `min:N` | Numeric value ≥ N, or string length ≥ N |
| `max:N` | Numeric value ≤ N, or string length ≤ N |
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

## Conditional rules

| Rule | Notes |
|---|---|
| `required_if:other,value` | Required when `other` equals `value` |
| `required_unless:other,value` | Required unless `other` equals `value` |
| `required_with:other` | Required when `other` is present |
| `required_without:other` | Required when `other` is absent |

## Database rules

| Rule | Notes |
|---|---|
| `unique:table,column[,except_id,id_column]` | No other row may have this value |
| `exists:table[,column]` | A row with this value must exist |

Configure the resolver once in your app:

```perl
# DBIx::Class — nothing to configure if your app has $app->schema
$app->plugin('FormRequest');

# Raw DBI
$app->plugin('FormRequest', db => sub { $c->dbh });
```

## Updating a record — excluding the current row from `unique`

When a user updates their profile without changing their email, the email is
already in the database (in their own row). A plain `unique:users,email` would
reject the request because the value exists. The fix is to pass `except_id`
and `id_column` as the third and fourth arguments:

```
unique:table,column,except_id,id_column
```

- `except_id` — the ID of the row to exclude (the record being updated)
- `id_column` — the primary key column (defaults to `id`)

With `except_id`, the query becomes:

```sql
SELECT COUNT(*) FROM users WHERE email = ? AND id != ?
```

The user's own row is excluded, so the count is `0` and validation passes.

### Update form request

```perl
package MyApp::Requests::UpdateUser;
use Mojo::Base 'Mojolicious::Plugin::FormRequest::Base', -signatures;

sub rules ($self, $c) {
  my $user_id = $c->stash('user_id');

  return {
    name  => 'required|min:3',
    email => "required|email|unique:users,email,$user_id,id",
  };
}

1;
```

### Fluent equivalent

```perl
use Mojolicious::Plugin::FormRequest::Rule;

sub rules ($self, $c) {
  my $user_id = $c->stash('user_id');

  return {
    email => [
      'required',
      'email',
      Mojolicious::Plugin::FormRequest::Rule
        ->unique('users', 'email')
        ->ignore($user_id),
    ],
  };
}
```

### Create form request

For `POST` (create), the user has no ID yet — do **not** pass `except_id`:

```perl
sub rules ($self, $c) {
  return { email => 'required|email|unique:users,email' };
}
```

Or, when the same class handles both create and update:

```perl
sub rules ($self, $c) {
  my $id = $c->stash('user_id');
  my $email_rule = $id
    ? "unique:users,email,$id,id"
    : 'unique:users,email';

  return {
    email => "required|email|$email_rule",
  };
}
```

### Test it explicitly

```perl
# user 1 already has email 'taken@example.com'
# user 1 updates their own email to 'taken@example.com' -> should pass
$t->post_ok('/user/1' => form => { email => 'taken@example.com' })
  ->status_is(200);

# user 2 tries to take user 1's email -> should fail
$t->post_ok('/user/2' => form => { email => 'taken@example.com' })
  ->status_is(422)
  ->json_like('/errors/email' => qr/already been taken/);
```

### Caveats

- If `except_id` is `undef`, the rule falls back to "check all rows" — correct for create, wrong for update. Always pass a real ID on the update route.
- `except_id` is bound with `?`, not interpolated into the SQL, so it is safe from injection. The identifier `id_column` is validated against `/\A[A-Za-z_][A-Za-z0-9_]*\z/`.

## Wildcards

Wildcard rules validate every element of a nested array. Use `*` for the
array index:

```perl
sub rules ($self, $c) {
  return {
    'items'        => 'required|array',
    'items.*.name' => 'required|string|min:2',
    'items.*.qty'  => 'required|integer|min:1',
  };
}
```

### What "every element" means

If the request contains `items[0][name]=apple`, `items[0][qty]=3`,
`items[1][name]=banana`, `items[1][qty]=5`, the plugin checks:

- `items.0.name` → `apple` → must be a string, at least 2 chars
- `items.0.qty`  → `3`     → must be an integer, at least 1
- `items.1.name` → `banana` → must be a string, at least 2 chars
- `items.1.qty`  → `5`     → must be an integer, at least 1

If `items[1][name]` is **not sent at all**, the plugin still checks
`items.1.name` against `required` — because `items.1.qty` exists, which
tells the plugin that index `1` is part of the array. The rule fails with
an error keyed `items.1.name`. This is the Laravel behaviour: the shape
of the array comes from the fields that exist, not from a separate count.

### Error keys use dot notation

A failure on `items[1][name]` produces the error key `items.1.name`:

```json
{
  "ok": 0,
  "errors": {
    "items.1.name": "is required"
  }
}
```

In a template you can walk the errors:

```ep
% if (my $errors = flash 'errors') {
  <ul>
  % for my $field (sort keys %$errors) {
    <li><strong><%= $field %>:</strong> <%= $errors->{$field} %></li>
  % }
  </ul>
% }
```

### Nested wildcards

Two levels:

```perl
sub rules ($self, $c) {
  return {
    'orders.*.items.*.sku' => 'required|string',
    'orders.*.items.*.qty' => 'required|integer|min:1',
  };
}
```

The request shape is `orders[0][items][0][sku]=ABC` etc. The resolver walks
the flat parameters, joins them with dots, and validates each combination.

### Arrays of scalars

To validate an array of strings (not hashes):

```perl
sub rules ($self, $c) {
  return {
    'tags'   => 'required|array',
    'tags.*' => 'required|string|min:2',
  };
}
```

Request: `tags[]=perl&tags[]=mojo&tags[]=cpan`. Each tag is checked
against `required|string|min:2`. A failure on the second tag produces the
key `tags.1`.

### JSON bodies

Wildcards work identically for JSON requests:

```bash
curl -s -X POST http://localhost:3000/check \
  -H 'Content-Type: application/json' \
  -d '{"items":[{"name":"apple","qty":3},{"name":"banana","qty":5}]}'
```

The plugin merges `$c->req->json` into the flat parameters, so
`items.*.name` matches `items.0.name` and `items.1.name` without
changes.

### `distinct` on an array

`distinct` checks that an array contains no duplicate values:

```perl
sub rules ($self, $c) {
  return {
    'tags' => 'required|array|distinct',
  };
}
```

`["perl","mojo","perl"]` fails with `"tags":"has a duplicate value"`.
`["perl","mojo","cpan"]` passes. Note that `distinct` only fires on real
arrays — a form-encoded `tags=a,b,c` is a scalar string and `distinct`
returns 1 (passes) without checking. Send the field as a JSON array or
use `tags[]=...` in the form to get a real array.

### Caveats

- Wildcard errors stop at the first failing element per field **only when `stop_on_first_failure` is true** (the default). With `stop_on_first_failure` set to `0`, every failing element is collected.
- If the entire array is missing (no `items[0][name]`, no `items[0][qty]`), the wildcard pattern matches zero targets and the plugin does **not** synthesize a `required` error for `items.*.name`. Add a separate `'items' => 'required|array'` rule to enforce the array's presence.
- Wildcard resolution reads the **flat** parameter keys, not a nested hash. `items[0][name]` and `items.0.name` are treated identically.

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

## File uploads

File uploads are stored by Mojolicious in `$c->req->upload(...)`, not in
`$c->req->params`. The plugin validates the form fields around the file;
the controller reads and stores the file.

### Form Request (fields only)

```perl
package MyApp::Requests::UploadAvatar;
use Mojo::Base 'Mojolicious::Plugin::FormRequest::Base', -signatures;

sub rules ($self, $c) {
  return {
    username    => 'required|min:3',
    description => 'nullable|max:200',
  };
}

sub messages ($self, $c) {
  return {
    'username.required' => 'Please enter your name',
    'username.min'      => 'Name must be at least :min characters',
  };
}

1;
```

### Controller — HTML form with Flash

```perl
sub upload_avatar ($self) {
  my $res = $self->form_request('MyApp::Requests::UploadAvatar')->validate;

  my $file = $self->req->upload('avatar');

  my %errors = %{ $res->{errors} || {} };
  if (!$file) {
    $errors{avatar} = 'Please choose an avatar file';
  }
  elsif ($file->size > 2 * 1024 * 1024) {
    $errors{avatar} = 'Avatar must be smaller than 2 MB';
  }
  else {
    my $ext = ($file->filename =~ /\.(\w+)$/) ? lc($1) : '';
    unless ($ext =~ /\A(jpe?g|png|gif)\z/) {
      $errors{avatar} = 'Avatar must be a JPEG, PNG or GIF';
    }
  }

  if (%errors) {
    $self->flash(errors => \%errors);
    $self->flash(old    => { username => $self->param('username') // '' });
    return $self->redirect_to('profile_form');
  }

  my $ext  = ($file->filename =~ /\.(\w+)$/) ? lc($1) : 'bin';
  my $name = 'avatar_' . time() . ".$ext";
  $file->move_to($self->app->home->child('public', 'uploads', $name));

  $self->flash(success => 'Avatar updated');
  $self->redirect_to('profile_form');
}
```

### Controller — JSON response

```perl
sub upload_avatar ($self) {
  my $res = $self->form_request('MyApp::Requests::UploadAvatar')->validate;
  unless ($res->{ok}) {
    return $self->render(json => { ok => 0, errors => $res->{errors} }, status => 422);
  }

  my $file = $self->req->upload('avatar');
  unless ($file) {
    return $self->render(json => { ok => 0, errors => { avatar => 'is required' } }, status => 422);
  }
  unless ($file->size <= 2 * 1024 * 1024) {
    return $self->render(json => { ok => 0, errors => { avatar => 'must be smaller than 2 MB' } }, status => 422);
  }

  my $ext = ($file->filename =~ /\.(\w+)$/) ? lc($1) : 'bin';
  unless ($ext =~ /\A(jpe?g|png|gif)\z/) {
    return $self->render(json => { ok => 0, errors => { avatar => 'must be a JPEG, PNG or GIF' } }, status => 422);
  }

  my $name = "avatar_" . time() . ".$ext";
  $file->move_to($self->app->home->child('public', 'uploads', $name));

  $self->render(json => {
    ok   => 1,
    user => $res->{data}{username},
    file => "/uploads/$name",
  });
}
```

### Template

```ep
<%= form_for profile_submit => (method => 'post', enctype => 'multipart/form-data') => begin %>
  <div class="form-group">
    <label for="username">Username</label>
    <input type="text" name="username" id="username"
           value="<%= flash('old')->{username} // '' %>">
  </div>

  <div class="form-group">
    <label for="avatar">Avatar (JPEG / PNG / GIF, max 2 MB)</label>
    <input type="file" name="avatar" id="avatar">
  </div>

  <button type="submit" class="btn btn-primary">Save</button>
<% end %>
```

### Sending the request

```bash
curl -s -X POST http://localhost:3000/upload_avatar \
  -F 'username=alice' \
  -F 'description=my new avatar' \
  -F 'avatar=@/tmp/me.jpg'
```

### Testing with `Test::Mojo`

```perl
$t->post_ok('/upload_avatar' => form => {
  username => 'Alice',
  avatar   => { file => '/tmp/me.jpg', filename => 'me.jpg' },
})
  ->status_is(302)
  ->header_is(Location => '/profile');
```

`form => { avatar => { file => ... } }` is `Test::Mojo`'s multipart upload syntax.

### Caveats

- File inputs cannot be repopulated by the template — browsers forbid it. The user must re-select the file after a failed submit.
- The plugin's `required` rule applies to `$c->req->params`, not to uploads. The controller checks `$self->req->upload('avatar')` explicitly.
- If you want the plugin to validate files natively (`file`, `mimes`, `max` in KB, `dimensions`), this is a planned extension. Until then, the controller does the three `if` checks shown above.

## Using it for JSON responses

`validate_or_fail` renders a 422 JSON body directly on failure. This is the shortest path for API endpoints:

```perl
sub store ($self) {
  my $data = $self->form_request('MyApp::Requests::StoreUser')->validate_or_fail;
  return unless defined $data;
  $self->render(json => { created => $data });
}
```

On success: `{"created":{"name":"Alice","email":"a@b.co"}}`

On failure: `{"ok":0,"errors":{"email":"is required","name":"must be at least 3 characters"}}` with HTTP 422.

The response is already rendered — do not call `$self->render` again after `validate_or_fail` returns `undef`, or you will get a "response already rendered" error.

## Using it for HTML forms (Flash + template)

`validate_or_fail` renders a response directly, which bypasses Flash. For template-based forms, the pattern is:

1. Call `validate` instead of `validate_or_fail`.
2. Store `errors` and the previously submitted fields (`old`) in Flash.
3. `redirect_to` the form page.
4. Read the Flash in the template.

### Form Request

```perl
package MyApp::Requests::StoreUser;
use Mojo::Base 'Mojolicious::Plugin::FormRequest::Base', -signatures;

sub rules ($self, $c) {
  return {
    username    => 'required|min:3|max:50',
    description => 'nullable|max:200',
  };
}

sub messages ($self, $c) {
  return {
    'username.required' => 'Please enter your name',
    'username.min'      => 'Name must be at least :min characters',
  };
}

1;
```

### Controller

```perl
sub form ($self) {
  # Renders the form. Flash errors and old input are read by the template.
  $self->render('profile/form');
}

sub submit ($self) {
  my $res = $self->form_request('MyApp::Requests::StoreUser')->validate;

  unless ($res->{ok}) {
    $self->flash(errors => $res->{errors});
    $self->flash(old    => {
      username    => $self->param('username')    // '',
      description => $self->param('description') // '',
    });
    return $self->redirect_to('profile_form');
  }

  # Validation passed
  $self->flash(success => 'Profile updated successfully');
  $self->redirect_to('profile_form');
}
```

`DefaultHelpers` provides `flash` and is enabled by default in `mojo generate app`. If you use `Mojolicious::Lite`, add `plugin 'DefaultHelpers'` yourself.

### Routes

```perl
sub startup ($self) {
  my $self = shift;
  $self->plugin('FormRequest');

  my $r = $self->routes;
  $r->get('/profile')->name('profile_form')->to('profile#form');
  $r->post('/profile')->name('profile_submit')->to('profile#submit');
}
```

### Template — `templates/profile/form.html.ep`

```ep
% layout 'default';
% title 'My Profile';

<h1>My Profile</h1>

% if (my $success = flash 'success') {
  <div class="alert alert-success"><%= $success %></div>
% }

% if (my $errors = flash 'errors') {
  <div class="alert alert-danger">
    <ul>
    % for my $field (sort keys %$errors) {
      <li><strong><%= $field %>:</strong> <%= $errors->{$field} %></li>
    % }
    </ul>
  </div>
% }

% my $old = flash('old') // {};

<%= form_for profile_submit => (method => 'post', enctype => 'multipart/form-data') => begin %>
  <div class="form-group">
    <label for="username">Username</label>
    <input type="text" name="username" id="username"
           value="<%= $old->{username} // '' %>">
  </div>

  <div class="form-group">
    <label for="description">Description</label>
    <textarea name="description" id="description"><%= $old->{description} // '' %></textarea>
  </div>

  <button type="submit" class="btn btn-primary">Save</button>
<% end %>
```

### Behaviour

- `GET /profile` — no Flash, empty form.
- `POST /profile` with invalid data — controller stores `errors` and `old` in Flash, redirects to `GET /profile`. The template reads `flash 'errors'` and renders a red error list, and reads `flash 'old'` to repopulate `username` and `description` so the user does not retype them.
- `POST /profile` with valid data — controller stores `success` in Flash, redirects. The template reads `flash 'success'` and renders a green success box.

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

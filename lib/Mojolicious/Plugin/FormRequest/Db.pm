package Mojolicious::Plugin::FormRequest::Db;
use Mojo::Base -base, -signatures;

has 'c';
has 'resolver';

sub _resolve_db ($self) {
  my $c = $self->c;
  if (my $r = $self->resolver) {
    return $r->($c);
  }
  my $app = $c->app;
  return $app->schema if $app->can('schema');
  return undef;
}

sub exists ($self, $table, $column, $value) {
  my $db = $self->_resolve_db or die "FormRequest: no database configured";
  return $self->_count($db, $table, $column, $value, undef) > 0;
}

sub unique ($self, $table, $column, $value, $except_id, $id_column) {
  my $db = $self->_resolve_db or die "FormRequest: no database configured";
  $id_column //= 'id';
  my $except = defined $except_id ? [$id_column, $except_id] : undef;
  return $self->_count($db, $table, $column, $value, $except) == 0;
}

sub _count ($self, $db, $table, $column, $value, $except) {
  if (ref $db && $db->isa('DBIx::Class::Schema')) {
    return $self->_count_rs($db, $table, $column, $value, $except);
  }
  return $self->_count_dbh($db, $table, $column, $value, $except);
}

sub _count_rs ($self, $schema, $table, $column, $value, $except) {
  my $rs = $schema->resultset($table)->search({ $column => $value });
  $rs = $rs->search({ $except->[0] => { '!=' => $except->[1] } }) if $except;
  return $rs->count;
}

sub _count_dbh ($self, $dbh, $table, $column, $value, $except) {
  for my $id ($table, $column, ($except ? $except->[0] : ())) {
    die "FormRequest: unsafe SQL identifier '$id'"
      unless defined $id && $id =~ /\A[A-Za-z_][A-Za-z0-9_]*\z/;
  }

  my $sql = "SELECT COUNT(*) FROM $table WHERE $column = ?";
  my @bind = ($value);
  if ($except) {
    $sql .= " AND $except->[0] != ?";
    push @bind, $except->[1];
  }
  my $sth = $dbh->prepare($sql);
  $sth->execute(@bind);
  my ($n) = $sth->fetchrow_array;
  $sth->finish;
  return $n // 0;
}

1;

__END__

=head1 NAME

Mojolicious::Plugin::FormRequest::Db - Database adapter for unique/exists rules

=head1 DESCRIPTION

Wraps a DBIx::Class schema or raw DBI handle.

=head1 TRUSTED

=over 4

=item exists

=item unique

=back

=cut

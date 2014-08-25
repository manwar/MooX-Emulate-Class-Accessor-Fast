package MooX::Emulate::Class::Accessor::Fast;
use Moo::Role;

=head1 NAME

MooX::Emulate::Class::Accessor::Fast - Emulate Class::Accessor::Fast behavior using Moo attributes

=head1 SYNOPSYS

    package MyClass;
    use Moo;

    with 'MooX::Emulate::Class::Accessor::Fast';


    #fields with readers and writers
    __PACKAGE__->mk_accessors(qw/field1 field2/);
    #fields with readers only
    __PACKAGE__->mk_ro_accessors(qw/field3 field4/);
    #fields with writers only
    __PACKAGE__->mk_wo_accessors(qw/field5 field6/);


=head1 DESCRIPTION

This module attempts to emulate the behavior of L<Class::Accessor::Fast> as
accurately as possible using the Moo attribute system. The public API of
C<Class::Accessor::Fast> is wholly supported, but the private methods are not.
If you are only using the public methods (as you should) migration should be a
matter of switching your C<use base> line to a C<with> line.

While I have attempted to emulate the behavior of Class::Accessor::Fast as closely
as possible bugs may still be lurking in edge-cases.

=head1 BEHAVIOR

Simple documentation is provided here for your convenience, but for more thorough
documentation please see L<Class::Accessor::Fast> and L<Class::Accessor>.

=head2 A note about introspection

Please note that, at this time, the C<is> flag attribute is not being set. To
determine the C<reader> and C<writer> methods using introspection in later versions
of L<Class::MOP> ( > 0.38) please use the C<get_read_method> and C<get_write_method>
methods in L<Class::MOP::Attribute>. Example

    # with Class::MOP <= 0.38
    my $attr = $self->meta->find_attribute_by_name($field_name);
    my $reader_method = $attr->reader || $attr->accessor;
    my $writer_method = $attr->writer || $attr->accessor;

    # with Class::MOP > 0.38
    my $attr = $self->meta->find_attribute_by_name($field_name);
    my $reader_method = $attr->get_read_method;
    my $writer_method = $attr->get_write_method;

=head1 METHODS

=head2 BUILD $self %args

Change the default Moo class building to emulate the behavior of C::A::F and
store arguments in the instance hashref.

=cut

use Class::Method::Modifiers qw( install_modifier );
use Carp qw( confess );

sub BUILD { }

around BUILD => sub {
  my $orig = shift;
  my $self = shift;

  my %args = %{ $_[0] };
  $self->$orig(\%args);

  my @extra = grep { !exists($self->{$_}) } keys %args;
  @{$self}{@extra} = @args{@extra};

  return $self;
};

=head2 mk_accessors @field_names

Create read-write accessors. An attribute named C<$field_name> will be created.
The name of the c<reader> and C<writer> methods will be determined by the return
value of C<accessor_name_for> and C<mutator_name_for>, which by default return the
name passed unchanged. If the accessor and mutator names are equal the C<accessor>
attribute will be passes to Moo, otherwise the C<reader> and C<writer> attributes
will be passed. Please see L<Class::MOP::Attribute> for more information.

=cut

sub mk_accessors {
  my ($class, @fields) = @_;

  foreach my $field (@fields) {
    $class->make_accessor( $field );
  }

  return;
}

=head2 mk_ro_accessors @field_names

Create read-only accessors.

=cut

sub mk_ro_accessors {
  my ($class, @fields) = @_;

  foreach my $field (@fields) {
    $class->make_ro_accessor( $field );
  }

  return;
}

=head2 mk_ro_accessors @field_names

Create write-only accessors.

=cut

sub mk_wo_accessors {
  my ($class, @fields) = @_;

  foreach my $field (@fields) {
    $class->make_wo_accessor( $field );
  }

  return;
}

=head2 follow_best_practices

Preface readers with 'get_' and writers with 'set_'.
See original L<Class::Accessor> documentation for more information.

=cut

sub follow_best_practice {
  my ($class) = @_;

  my $fresh = sub{ install_modifier($class, 'fresh', @_) };

  $fresh->(
    mutator_name_for => sub{ 'set_' . $_[1] },
  );

  $fresh->(
    accessor_name_for => sub{ 'get_' . $_[1] },
  );

  return;
}

=head2 mutator_name_for

=head2 accessor_name_for

See original L<Class::Accessor> documentation for more information.

=cut

sub mutator_name_for  { $_[1] }
sub accessor_name_for { $_[1] }

=head2 set

See original L<Class::Accessor> documentation for more information.

=cut

sub set {
  my $self = shift;
  my $field = shift;
  confess "Wrong number of arguments received" unless scalar @_;

  $self->{$field} = (@_>1) ? [@_] : @_;

  return;
}

=head2 get

See original L<Class::Accessor> documentation for more information.

=cut

sub get {
  my $self = shift;
  confess "Wrong number of arguments received" unless scalar @_;

  my @values = (
    map { $self->{$_} }
    @_
  );

  return @values;
}


sub make_accessor {
  my ($class, $name) = @_;

  my $reader = $class->accessor_name_for( $field );
  my $writer = $class->mutator_name_for( $field );

  my $alias;

  if ($reader eq $writer and $reader eq $field) {
    # Do nothing.
  }
  elsif ($reader ne $writer) {
    $reader = undef if $reader eq $field;
    $writer = undef if $writer eq $field;
  }
  else {
    $alias = $reader;
  }

  $class->can('has')->(
    $field,
    is => 'rw',
    $reader ? (reader=>$reader) : (),
    $writer ? (writer=>$writer) : (),
  );

  if ($alias) {
    install_modifier(
      $class, 'fresh', $alias,
      sub{ shift()->$field(@_) },
    });
  }

  my $reader_method = $alias || $reader || $field;
  my $writer_method = $alias || $writer || $field;

  return sub{
    my $self = shift;
    return $self->$writer_method( @_ ) if @_;
    return $self->$reader_method();
  };
}

sub make_ro_accessor {
  my ($class, $field) = @_;

  my $reader = $class->accessor_name_for( $field );
  $reader = undef if $reader eq $field;

  $class->can('has')->(
    $field,
    is => 'ro',
    $reader ? (reader=>$reader) : (),
  );

  $reader_method = $reader || $field;

  return sub{
    my $self = shift;
    return $self->$reader_method();
  };
}

sub make_wo_accessor {
  my ($class, $field) = @_;

  my $writer = $class->mutator_name_for( $field );
  $writer = undef if $writer eq $field;
  my $reader = "__get__$field";

  $class->can('has')->(
    $field,
    is => 'rw',
    reader => $reader,
    $writer ? (writer=>$writer) : (),
  );

  $class->can('around')->(
    $reader,
    sub { die "Cannot call $reader" },
  );

  my $writer_method = $writer || $field;

  return sub{
    my $self = shift;
    return $self->$writer_method( @_ );
  };
}

1;
__END__

=head1 SEE ALSO

L<Moo>, L<Moo::Meta::Attribute>, L<Class::Accessor>, L<Class::Accessor::Fast>,
L<Class::MOP::Attribute>, L<MooX::Adopt::Class::Accessor::Fast>

=head1 AUTHORS

Guillermo Roditi (groditi) E<lt>groditi@cpan.orgE<gt>

With contributions from:

=over 4

=item Tomas Doran (t0m) E<lt>bobtfish@bobtfish.netE<gt>

=item Florian Ragwitz (rafl) E<lt>rafl@debian.orgE<gt>

=back

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.

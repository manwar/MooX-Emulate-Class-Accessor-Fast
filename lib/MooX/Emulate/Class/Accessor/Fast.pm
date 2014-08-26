package MooX::Emulate::Class::Accessor::Fast;
use Moo::Role;
use strictures 1;

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

use Package::Stash;
use Class::Method::Modifiers qw( install_modifier );
use Carp qw( croak );

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

=head2 follow_best_practice

Preface readers with 'get_' and writers with 'set_'.
See original L<Class::Accessor> documentation for more information.

=cut

sub follow_best_practice {
  my ($class) = @_;

  my $stash = Package::Stash->new( $class );

  $stash->add_symbol(
    '&mutator_name_for',
    sub{ 'set_' . $_[1] },
  );

  $stash->add_symbol(
    '&accessor_name_for',
    sub{ 'get_' . $_[1] },
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

  my $method = "_set_moocaf_$field";
  return $self->$method( @_ );
}

=head2 get

See original L<Class::Accessor> documentation for more information.

=cut

sub get {
  my $self = shift;

  my @values;
  foreach my $field (@_) {
    my $method = "_get_moocaf_$field";
    push @values, $self->$method();
  }

  return $values[0] if @values==1;
  return @values;
}

sub _make_moocaf_accessor {
  my ($class, $field, $type) = @_;

  if (!$class->can('has')) {
    require Moo;
    my $ok = eval "package $class; Moo->import(); 1";
    croak "Failed to import Moo into $class" if !$ok;
  }

  my $private_reader = "_get_moocaf_$field";
  my $private_writer = "_set_moocaf_$field";

  if (!$class->can($private_reader)) {
    $class->can('has')->(
      $field,
      is     => 'rw',
      reader => $private_reader,
      writer => $private_writer,
    );

    install_modifier(
      $class, 'around', $private_writer,
      sub{
        my $orig = shift;
        my $self = shift;
        return $self->$orig() if !@_;
        my $value = (@_>1) ? [@_] : $_[0];
        $self->$orig( $value );
        return $self;
      },
    );
  }

  my $reader = $class->accessor_name_for( $field );
  my $writer = $class->mutator_name_for( $field );

  $reader = undef if $type eq 'wo';
  $writer = undef if $type eq 'ro';

  my $stash = Package::Stash->new( $class );

  if (($reader and $writer) and ($reader eq $writer)) {
    $stash->add_symbol(
      '&' . $reader,
      sub{
        my $self = shift;
        return $self->$private_reader() if !@_;
        return $self->$private_writer( @_ );
      },
    ) if !$stash->has_symbol('&' . $reader);
  }
  else {
    $stash->add_symbol(
      '&' . $reader,
      sub{ shift()->$private_reader( @_ ) },
    ) if $reader and !$stash->has_symbol('&' . $reader);

    $stash->add_symbol(
      '&' . $writer,
      sub{ shift()->$private_writer( @_ ) },
    ) if $writer and !$stash->has_symbol('&' . $writer);
  }

  return sub{
    my $self = shift;
    return $self->$private_reader( @_ ) unless @_ and $type ne 'wo';
    return $self->$private_writer( @_ );
  };
}

sub make_accessor {
  my ($class, $field) = @_;
  return $class->_make_moocaf_accessor( $field, 'rw' );
}

sub make_ro_accessor {
  my ($class, $field) = @_;
  return $class->_make_moocaf_accessor( $field, 'ro' );
}

sub make_wo_accessor {
  my ($class, $field) = @_;
  return $class->_make_moocaf_accessor( $field, 'wo' );
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

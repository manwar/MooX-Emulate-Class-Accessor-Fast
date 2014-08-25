package MooX::Adopt::Class::Accessor::Fast;

$INC{'Class/Accessor/Fast.pm'} = __FILE__;

package #don't index
    Class::Accessor::Fast;

use Moo;
with 'MooX::Emulate::Class::Accessor::Fast';

1;

=head1 NAME

MooX::Adopt::Class::Accessor::Fast -
  Hijack Class::Accessor::Fast in %INC;

=head1 SYNOPSYS

    use MooX::Adopt::Class::Accessor::Fast;
    use CAF::Using::Module;
    #that's it! JustWorks

=head1 DESCRIPTION

This module attempts to hijack L<Class::Accessor::Fast> in %INC and replace it
with L<MooX::Emulate::Class::Accessor::Fast>. Make sure it is loaded before the
classes you have that use <Class::Accessor::Fast>. It is meant as a tool to help
you migrate your project from L<Class::Accessor::Fast>, to
 L<MooX::Emulate::Class::Accessor::Fast> and ultimately, to L<Moo>.

=head1 SEE ALSO

L<Moo>, L<Class::Accessor::Fast>, L<MooX::Emulate::Class::Accessor::Fast>

=head1 AUTHORS

=over 4

=item Matt S Trout

=item Guillermo Roditi (groditi) <groditi@cpan.org>

=back

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.

=cut


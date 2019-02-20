#!/usr/bin/env perl
use strict;
use warnings;
use Test2::V0;

use MooX::Adopt::Class::Accessor::Fast;

{
  package Some::Class;
  use base qw/Class::Accessor::Fast/;

  __PACKAGE__->mk_accessors(qw/ foo /);
}

my $i = bless {}, 'Some::Class';
$i->foo(qw/bar baz/);
is($i->foo, [qw/ bar baz /]);

done_testing;

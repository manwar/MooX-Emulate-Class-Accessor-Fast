
requires 'Moo' => 1.004005;
requires 'strictures' => 1.004004;
requires 'Class::Method::Modifiers' => 2.05;
requires 'Package::Stash' => 0.26;
requires 'Carp' => 0;

on test => sub {
    requires 'Test::Simple' => 0.94;
    requires 'Test::Exception'  => 0;
};

use FixMyStreet::TestMech;

use_ok 'FixMyStreet::Cobrand::TransportFocus';

my $mech = FixMyStreet::TestMech->new;

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'transportfocus',
}, sub {
    $mech->get_ok('/');
    $mech->content_contains('Sort My Sign');
};

done_testing;
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;

use_ok 'FixMyStreet::Cobrand::TransportFocus';

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok(11809, 'Highways England');
my $contact = $mech->create_contact_ok(
    body => $body, category => 'Missing', email => 'missing@example.org');

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'transportfocus',
}, sub {
    $mech->get_ok('/');
    $mech->content_contains('Sort My Sign');

    $mech->create_problems_for_body(1, $body->id, 'Title', {
        category => 'Missing',
        cobrand => 'transportfocus',
    });
    FixMyStreet::Script::Reports::send();

    my @emails = $mech->get_email;
    my $email = $mech->get_text_body_from_email($emails[0]);
    like $email, qr/A user of Sort My Sign/;
    $email = $mech->get_text_body_from_email($emails[1]);
    like $email, qr/Thank you for taking part/;
};

done_testing;
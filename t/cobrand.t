use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;

FixMyStreet::App->log->disable('info');

use_ok 'FixMyStreet::Cobrand::TransportFocus';

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok(11809, 'Highways England');
my $contact = $mech->create_contact_ok(
    body => $body, category => 'Missing', email => 'missing@example.org');

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'transportfocus',
    MAPIT_URL => 'http://mapit.uk',
    MAPIT_TYPES => ['EUR'],
}, sub {
    $mech->log_in_ok('user@example.org');

    $mech->get_ok('/');
    $mech->content_contains('Sort My Sign');

    $mech->get_ok('/around?lat=52.51093&lon=-1.86514');
    $mech->follow_link_ok({ text_regex => qr/skip this step/i });
    $mech->submit_form_ok({
        with_fields => {
            title => 'M6 northbound just by the RAC building',
            detail => 'Please put back the sign',
            name => 'Joe Bloggs',
            category => 'Missing',
            consent => 1,
            how_long => '3-6 months',
        }
    });

    my $report = FixMyStreet::DB->resultset("Problem")->first;
    $mech->get_ok('/report/' . $report->id);
    $mech->content_contains('3-6 months');

    FixMyStreet::Script::Reports::send();

    my @emails = $mech->get_email;
    my $email = $mech->get_text_body_from_email($emails[0]);
    like $email, qr/A user of Sort My Sign/;
    $email = $mech->get_text_body_from_email($emails[1]);
    like $email, qr/Thank you for taking part/;
};

done_testing;
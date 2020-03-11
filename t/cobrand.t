use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;
use Test::MockModule;

my $cobrand = Test::MockModule->new('FixMyStreet::Cobrand::TransportFocus');
$cobrand->mock('_lookup_db', sub {
    my ($road, $table, $thing, $thing_name) = @_;

    if ($road eq 'M6' && $thing eq '11') {
        return { latitude => 52.65866, longitude => -2.06447 };
    } elsif ($road eq 'M5' && $thing eq '132.5') {
        return { latitude => 51.5457, longitude => 2.57136 };
    }
});

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

    $mech->submit_form_ok({ with_fields => { pc => 'M6, Junction 11' } });
    $mech->content_contains('52.65866');

    $mech->get_ok('/');
    $mech->submit_form_ok({ with_fields => { pc => 'M5 132.5' } });
    $mech->content_contains('51.5457');

    $mech->get_ok('/around?lat=52.51093&lon=-1.86514');
    $mech->follow_link_ok({ text_regex => qr/skip this step/i });
    $mech->submit_form_ok({
        with_fields => {
            title => 'M6 northbound just by the RAC building',
            detail => 'Please put back the sign',
            name => 'Joe Bloggs',
            category => 'Missing',
            consent => 1,
            road_name => 'M6',
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

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'transportfocus',
    MAPIT_URL => 'http://mapit.uk',
    MAPIT_TYPES => ['UTA'], # Just so mock area list does not error
    COBRAND_FEATURES => { heatmap => { transportfocus => 1 } },
}, sub {
    $mech->get_ok('/dashboard/heatmap');
    $mech->get('/dashboard');
    is $mech->res->code, 404;

    my $user = $mech->log_in_ok('staff@example.org');
    $user->update({ from_body => $body->id });

    $mech->get_ok('/dashboard');
    $mech->follow_link_ok({ text => 'Reports' });
    $mech->content_contains('"Report ID",Where,Detail,"User Name",Email,Phone,Category,Subcategory,Created,Confirmed,Latitude,Longitude,Query,Region,Easting,Northing,"Report URL",Road,"How long"');
    $mech->content_contains('"Joe Bloggs",pkg-sort-my-signtcobrandt-user@example.org,,Missing,,');
    $mech->content_contains('M6,"3-6 months"');
};

done_testing;

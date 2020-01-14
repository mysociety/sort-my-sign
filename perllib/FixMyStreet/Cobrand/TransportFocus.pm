package FixMyStreet::Cobrand::TransportFocus;
use base 'FixMyStreet::Cobrand::Default';

use strict;
use warnings;
use FixMyStreet::DB;
use mySociety::MaPit;
use mySociety::PostcodeUtil;

sub country { 'GB' }

sub on_map_default_status { 'open' }

sub council_name { 'Highways England' }

sub all_reports_single_body { { name => $_[0]->council_name } }

sub updates_disallowed { 1 }

sub suppress_reporter_alerts { 1 }

sub send_questionnaires { 0 }

sub enable_category_groups { 1 }

sub report_sent_confirmation_email { 'id' }

sub report_form_extras { (
    { name => 'how_long', required => 1 },
    { name => 'consent', required => 1 },
    { name => 'road_name', required => 0 },
) }

sub body {
    FixMyStreet::DB->resultset('Body')->search({ name => 'Highways England' })->first;
}

sub area_check {
    my ( $self, $params, $context ) = @_;

    my $areas = $params->{all_areas};
    $areas = {
        map { $_->{id} => $_ }
        # If no country, is prefetched area and can assume is E
        grep { ($_->{country} || 'E') eq 'E' }
        values %$areas
    };
    return $areas if %$areas;

    my $error_msg = '<div class="beta-warning"><p>Sorry, this site only covers England.</p></div>';
    return ( 0, $error_msg );
}

sub enter_postcode_text {
    'Enter a location, road name or postcode';
}

# From UK.pm
sub disambiguate_location {
    return {
        country => 'gb',
        google_country => 'uk',
        bing_culture => 'en-GB',
        bing_country => 'United Kingdom'
    };
}

# From UK.pm, expanded
sub geocode_postcode {
    my ( $self, $s ) = @_;

    if ($s =~ /^\d+$/) {
        return {
            error => 'Sort My Sign is a UK-based website. Please enter either a UK postcode, or street name and area.'
        };
    } elsif (mySociety::PostcodeUtil::is_valid_postcode($s)) {
        my $location = mySociety::MaPit::call('postcode', $s);
        if ($location->{error}) {
            return {
                error => $location->{code} =~ /^4/
                    ? _('That postcode was not recognised, sorry.')
                    : $location->{error}
            };
        }
        my $island = $location->{coordsyst};
        if (!$island) {
            return {
                error => _("Sorry, that appears to be a Crown dependency postcode, which we don't cover.")
            };
        }
        return {
            latitude  => $location->{wgs84_lat},
            longitude => $location->{wgs84_lon},
        };
    }
    return {};
}

1;

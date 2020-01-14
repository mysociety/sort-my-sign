package FixMyStreet::Cobrand::TransportFocus;
use base 'FixMyStreet::Cobrand::Default';

use strict;
use warnings;
use FixMyStreet::DB;
use mySociety::MaPit;
use mySociety::PostcodeUtil;

sub on_map_default_status { return 'open'; }

sub body {
    FixMyStreet::DB->resultset('Body')->search({ name => 'Highways England' })->first;
}

sub problems_restriction {
    my ($self, $rs) = @_;
    return $rs if FixMyStreet->staging_flag('skip_checks');
    $rs = $rs->to_body($self->body);
    return $rs;
}

# From UK.pm, nothing else needed
#
sub disambiguate_location {
    return {
        country => 'gb',
        google_country => 'uk',
        bing_culture => 'en-GB',
        bing_country => 'United Kingdom'
    };
}

sub enter_postcode_text {
    'Enter a location, road name or postcode';
}

sub geocode_postcode {
    my ( $self, $s ) = @_;

    if ($s =~ /^\d+$/) {
        return {
            error => 'FixMyStreet is a UK-based website. Please enter either a UK postcode, or street name and area.'
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

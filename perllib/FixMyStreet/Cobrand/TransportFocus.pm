package FixMyStreet::Cobrand::TransportFocus;
use base 'FixMyStreet::Cobrand::Default';

use strict;
use warnings;
use FixMyStreet::DB;
use mySociety::MaPit;
use mySociety::PostcodeUtil;
use Utils;

sub country { 'GB' }

sub on_map_default_status { 'open' }

sub council_name { 'Highways England' }

sub all_reports_single_body { { name => $_[0]->council_name } }

sub updates_disallowed { 1 }

sub enable_category_groups { 1 }

sub report_sent_confirmation_email { 'id' }

sub reports_ordering { 'created-desc' }

sub report_form_extras { (
    { name => 'how_long', required => 1 },
    { name => 'consent', required => 1 },
    { name => 'road_name', required => 0 },
) }

sub body {
    FixMyStreet::DB->resultset('Body')->search({ name => 'Highways England' })->first;
}

sub dashboard_permission { $_[0]->body->id }

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
    } elsif ($s =~ /^\s*(?<road>[AM][0-9MT]*)[\s,.]*(junction|junc|j)\s*(?<junction>.*?)\s*$/i
          || $s =~ /^\s*(junction|junc|j)\s*(?<junction>.*?)[,.\s]*(?<road>[AM][0-9MT]*)\s*$/i
    ) {
        return _lookup_db($+{road}, 'junction', $+{junction}, 'name') || undef;
    } elsif ($s =~ /^\s*(?<road>[AM][^ ]*)\s*(?<dist>[0-9.]+)\s*$/i
          || $s =~ /^\s*(?<dist>[0-9.]+)\s*(?<road>[AM][^ ]*)\s*$/i
    ) {
        return _lookup_db($+{road}, 'sign', $+{dist}, 'distance') || undef;
    }
    return {};
}

sub _lookup_db {
    my ($road, $table, $thing, $thing_name) = @_;
    my $dbfile = FixMyStreet->path_to('../data/roads.sqlite');
    my $db = DBI->connect("dbi:SQLite:dbname=$dbfile", undef, undef) or return;
    $thing = "J$thing" if $table eq 'junction' && $thing =~ /^[1-9]/;
    my $results = $db->selectall_arrayref(
        "SELECT * FROM $table where road=? and $thing_name=?",
        { Slice => {} }, uc $road, uc $thing);
    if (@$results) {
        my ($lat, $lon) = Utils::convert_en_to_latlon($results->[0]{easting}, $results->[0]{northing});
        return { latitude => $lat, longitude => $lon };
    }
}

sub dashboard_export_problems_add_columns {
    my $self = shift;
    my $c = $self->{c};

    my $body = $self->body;
    my %groups = FixMyStreet::DB->resultset('Contact')->active->search({
        body_id => $self->body->id,
    })->group_lookup;

    splice @{$c->stash->{csv}->{headers}}, 5, 0, 'Subcategory';
    splice @{$c->stash->{csv}->{columns}}, 5, 0, 'subcategory';

    $c->stash->{csv}->{headers} = [
        grep { $_ !~ /Acknowledged|Fixed|Closed|Status|Site Used|Reported As/ }
        map {
            if ($_ eq 'Ward') { 'Region' }
            elsif ($_ eq 'Title') { 'Where' }
            else { $_ }
        } @{ $c->stash->{csv}->{headers} },
        "Road",
        "How long",
    ];

    $c->stash->{csv}->{columns} = [
        grep { $_ !~ /acknowledged|fixed|closed|state|site_used|reported_as/ }
        @{ $c->stash->{csv}->{columns} },
        "road_name",
        "how_long",
    ];

    $c->stash->{csv}->{extra_data} = sub {
        my $report = shift;
        my $fields = {
            road_name => $report->get_extra_metadata('road_name'),
            how_long => $report->get_extra_metadata('how_long'),
        };
        if ($groups{$report->category}) {
            $fields->{category} = $groups{$report->category};
            $fields->{subcategory} = $report->category;
        }
        return $fields;
    };
}

1;

(function(){

if (!fixmystreet.maps) {
    return;
}

function is_motorway(f) { return f && f.attributes && f.attributes.ROA_NUMBER && f.attributes.ROA_NUMBER.indexOf('M') > -1; }
function is_a_road(f) { return !is_motorway(f); }

var rule_motorway = new OpenLayers.Rule({
    filter: new OpenLayers.Filter.FeatureId({ type: OpenLayers.Filter.Function, evaluate: is_motorway }),
    symbolizer: { strokeColor: "#0079C1" }
});
var rule_a_road = new OpenLayers.Rule({
    filter: new OpenLayers.Filter.FeatureId({ type: OpenLayers.Filter.Function, evaluate: is_a_road }),
    symbolizer: { strokeColor: "#00703C" }
});

var highways_style = new OpenLayers.Style({ fill: false, strokeOpacity: 0.8, strokeWidth: 4 });
highways_style.addRules([rule_motorway, rule_a_road]);
var highways_stylemap = new OpenLayers.StyleMap({ 'default': highways_style });

var defaults = {
    wfs_url: "https://tilma.mysociety.org/mapserver/highways",
    body: 'Highways England',
    // this covers zoomed right out on Cumbrian sections of the M6
    max_resolution: 40,
    min_resolution: 0.0001,
    srsName: "EPSG:3857",
    strategy_class: OpenLayers.Strategy.FixMyStreet
};

fixmystreet.assets.add(defaults, {
    wfs_feature: "Highways",
    stylemap: highways_stylemap,
    always_visible: true,

    non_interactive: true,
    road: true,
    usrn: {
        field: 'road_name',
        attribute: 'ROA_NUMBER'
    },
    all_categories: true,

    // motorways are wide and the lines to define them are narrow so we
    // need a bit more margin for error in finding the nearest to stop
    // clicking in the middle of them being undetected
    nearest_radius: 50,
    asset_type: 'road',
    no_asset_msg_id: '#js-not-he-road',
    actions: {
        found: fixmystreet.message_controller.road_found,
        not_found: fixmystreet.message_controller.road_not_found
    }
});

})();


OpenLayers.Layer.Highways = OpenLayers.Class(OpenLayers.Layer.XYZ, {
    name: 'Highways',
    url: [
        "//tilma.mysociety.org/highways/${z}/${x}/${y}.png",
        "//a.tilma.mysociety.org/highways/${z}/${x}/${y}.png",
        "//b.tilma.mysociety.org/highways/${z}/${x}/${y}.png",
        "//c.tilma.mysociety.org/highways/${z}/${x}/${y}.png"
    ],
    sphericalMercator: true,
    isBaseLayer: false,
    CLASS_NAME: "OpenLayers.Layer.Highways"
});

$(function() {
    if (!fixmystreet.map) {
        return;
    }

    // Can't use vector layer on reports, too big, use tiles instead
    if (fixmystreet.page === 'reports') {
        var highways_layer = new OpenLayers.Layer.Highways(null, null, { className: 'olLayerHighways' });
        fixmystreet.map.addLayer(highways_layer);
        highways_layer.setVisibility(true);

        var qs = OpenLayers.Util.getParameters(fixmystreet.original.href);
        if (!qs.bbox && !qs.lat && !qs.lon) {
            var strategy = fixmystreet.markers.strategies[0];
            strategy.deactivate();
            var bounds = new OpenLayers.Bounds(-614115, 6468053, 195660, 7519292);
            var center = bounds.getCenterLonLat();
            var z = fixmystreet.map.getZoomForExtent(bounds);
            fixmystreet.map.setCenter(center, z);
            // Reactivate the strategy and make it think it's done an update
            strategy.activate();
            if (strategy instanceof OpenLayers.Strategy.BBOX) {
                strategy.calculateBounds();
                strategy.resolution = fixmystreet.map.getResolution();
            }
        }

        return;
    }

    // We want to show the asset layer on a report page
    if (fixmystreet.page !== 'report') {
        return;
    }

    var layer = fixmystreet.assets.layers[0];
    fixmystreet.map.addLayer(layer);

    var pins_layer = fixmystreet.map.getLayersByName("Pins")[0];
    if (pins_layer) {
        layer.setZIndex(pins_layer.getZIndex()-1);
    }
});

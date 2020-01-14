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
    // this covers zoomed right out on Cumbrian sections of
    // the M6
    max_resolution: 20,
    min_resolution: 0.5971642833948135,
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

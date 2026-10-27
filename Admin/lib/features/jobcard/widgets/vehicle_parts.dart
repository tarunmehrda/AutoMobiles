import 'package:flutter/material.dart';

import '../../../core/i18n/strings.dart';
import 'vehicle_blueprint.dart';

/// The named components a dent can be pinned to, laid out over the blueprint
/// views so a tap lands on the part it is drawn on.
///
/// Part names and ids follow the taxonomy published by MonkVision in
/// `@monkvision/types` (github.com/monkvision/monkjs, The Clear BSD License,
/// (c) 2022 Monk) wherever a panel maps cleanly onto it — `door_front_right`,
/// `bumper_back`, `grill_radiator` and so on. Borrowing a taxonomy an insurer
/// already reads beats inventing a private one, and the two- and three-wheeler
/// and truck panels, which it has no entries for, are named to the same
/// pattern.

/// One face of the vehicle, the way the counter thinks about it: the four
/// flanks, what you see standing over it, and what is inside.
enum VehicleArea { front, driver, passenger, rear, roof, interior, underbody }

extension VehicleAreaX on VehicleArea {
  /// The chip caption. A car has a driver's and a passenger's flank; a bike
  /// just has a right and a left, and calling those "passenger side" would be
  /// nonsense on a vehicle nobody sits beside you on.
  String label(VehicleKind kind) {
    final seated =
        kind == VehicleKind.fourWheeler ||
        kind == VehicleKind.sixWheeler ||
        kind == VehicleKind.threeWheeler;
    return switch (this) {
      VehicleArea.front => 'Front'.tr,
      VehicleArea.driver => seated ? 'Driver'.tr : 'Right'.tr,
      VehicleArea.passenger => seated ? 'Passenger'.tr : 'Left'.tr,
      VehicleArea.rear => 'Rear'.tr,
      VehicleArea.roof => kind == VehicleKind.twoWheeler ? 'Top'.tr : 'Roof'.tr,
      VehicleArea.interior =>
        kind == VehicleKind.twoWheeler ? 'Controls'.tr : 'Interior'.tr,
      VehicleArea.underbody => 'Underbody'.tr,
    };
  }

  /// The caption over the drawing.
  String heading(VehicleKind kind) => switch (this) {
    VehicleArea.driver ||
    VehicleArea.passenger => '{0} SIDE'.trf([label(kind).toUpperCase()]),
    _ => label(kind).toUpperCase(),
  };

  /// Which blueprint view the area is marked up on. The inside of the vehicle
  /// has no orthographic drawing, nor has the underside, so both are listed
  /// rather than plotted.
  String? get view => switch (this) {
    VehicleArea.front => 'front',
    VehicleArea.driver || VehicleArea.passenger => 'side',
    VehicleArea.rear => 'rear',
    VehicleArea.roof => 'top',
    VehicleArea.interior || VehicleArea.underbody => null,
  };

  /// Listed rather than drawn — see [view].
  bool get listed => view == null;

  IconData get icon => switch (this) {
    VehicleArea.front => Icons.arrow_upward_rounded,
    VehicleArea.driver => Icons.chair_alt_rounded,
    VehicleArea.passenger => Icons.airline_seat_recline_normal_rounded,
    VehicleArea.rear => Icons.arrow_downward_rounded,
    VehicleArea.roof => Icons.vertical_align_top_rounded,
    VehicleArea.interior => Icons.weekend_rounded,
    VehicleArea.underbody => Icons.vertical_align_bottom_rounded,
  };
}

/// Whether the side drawing has the nose pointing left.
///
/// These are right-hand-drive vehicles, so the flank you see with the nose to
/// your left is the driver's. Where the drawing already faces that way the
/// driver's side is used as drawn and the passenger's is its mirror; where it
/// faces the other way, the flip goes the other round. Nothing else has to
/// know which drawing was penned facing which way.
const Map<VehicleKind, bool> kSideFacesLeft = {
  VehicleKind.twoWheeler: false,
  VehicleKind.threeWheeler: true,
  VehicleKind.fourWheeler: true,
  VehicleKind.sixWheeler: true,
};

/// Whether an area's drawing is flipped before it is shown.
bool areaMirrored(VehicleKind kind, VehicleArea area) => switch (area) {
  VehicleArea.driver => !(kSideFacesLeft[kind] ?? true),
  VehicleArea.passenger => kSideFacesLeft[kind] ?? true,
  _ => false,
};

/// A component a dent can be pinned to.
@immutable
class VehiclePart {
  const VehiclePart({
    required this.id,
    required this.name,
    required this.area,
    required this.x,
    required this.y,
  });

  /// Stable, stored on the mark. Side-specific panels carry a `_right` or
  /// `_left` suffix so the same dent on the two flanks never collides.
  final String id;

  /// What it is called on screen.
  final String name;

  final VehicleArea area;

  /// Where the hotspot sits, 0..1 within the area's view box, given for the
  /// drawing as penned. Mirroring is applied when it is shown, not here.
  final double x;
  final double y;

  Offset get at => Offset(x, y);

  /// The name with its face, for the search list where the area is not
  /// otherwise on screen.
  String qualified(VehicleKind kind) => '$name · ${area.label(kind)}';
}

/// A panel that exists on both flanks and is listed against the side drawing.
@immutable
class _Flank {
  const _Flank(this.id, this.name, this.x, this.y, {this.sided = true});

  final String id;
  final String name;
  final double x;
  final double y;

  /// Whether there is one of these per flank. A front bumper is seen from
  /// both sides but is a single panel, so it keeps one id.
  final bool sided;
}

/// A component that sits on one of the head-on views.
@immutable
class _Spot {
  const _Spot(this.id, this.name, this.x, this.y);
  final String id;
  final String name;
  final double x;
  final double y;
}

// --- four wheeler ----------------------------------------------------------

const _fourSide = <_Flank>[
  _Flank('bumper_front', 'Front bumper', 0.065, 0.619, sided: false),
  _Flank('head_light', 'Headlamp', 0.095, 0.524),
  _Flank('hood', 'Bonnet', 0.180, 0.417, sided: false),
  _Flank('wheel_front', 'Front wheel', 0.210, 0.738),
  _Flank('fender_front', 'Front fender', 0.275, 0.536),
  _Flank('mirror', 'Wing mirror', 0.320, 0.357),
  _Flank('windshield_front', 'Windscreen', 0.365, 0.298, sided: false),
  _Flank('door_front', 'Front door', 0.410, 0.560),
  _Flank('window_front', 'Front door glass', 0.440, 0.310),
  _Flank('rocker_panel', 'Side sill', 0.500, 0.679),
  _Flank('pillar', 'Roof line', 0.505, 0.202, sided: false),
  _Flank('window_back', 'Rear door glass', 0.570, 0.310),
  _Flank('door_back', 'Rear door', 0.610, 0.560),
  _Flank('quarter_window_back', 'Quarter glass', 0.670, 0.310),
  _Flank('petrol_door', 'Fuel lid', 0.700, 0.524),
  _Flank('wheel_back', 'Rear wheel', 0.780, 0.738),
  _Flank('fender_back', 'Rear fender', 0.860, 0.536),
  _Flank('tail_light', 'Tail lamp', 0.930, 0.476),
  _Flank('bumper_back', 'Rear bumper', 0.950, 0.655, sided: false),
];

const _fourFront = <_Spot>[
  _Spot('windshield_front', 'Windscreen', 0.500, 0.239),
  _Spot('wiper_front', 'Wipers', 0.330, 0.300),
  _Spot('hood', 'Bonnet', 0.500, 0.391),
  _Spot('fender_front_right', 'RH front fender', 0.150, 0.391),
  _Spot('fender_front_left', 'LH front fender', 0.850, 0.391),
  _Spot('head_light_right', 'RH headlamp', 0.210, 0.500),
  _Spot('head_light_left', 'LH headlamp', 0.790, 0.500),
  _Spot('grill_radiator', 'Radiator grille', 0.500, 0.598),
  _Spot('bumper_front', 'Front bumper', 0.250, 0.750),
  _Spot('license_plate_front', 'Front number plate', 0.500, 0.761),
  _Spot('fog_light_front', 'Fog lamp', 0.730, 0.750),
];

const _fourRear = <_Spot>[
  _Spot('windshield_back', 'Rear windscreen', 0.500, 0.261),
  _Spot('wiper_back', 'Rear wiper', 0.360, 0.326),
  _Spot('trunk', 'Boot lid', 0.500, 0.457),
  _Spot('fender_back_right', 'RH rear fender', 0.140, 0.400),
  _Spot('fender_back_left', 'LH rear fender', 0.860, 0.400),
  _Spot('tail_light_right', 'RH tail lamp', 0.225, 0.500),
  _Spot('tail_light_left', 'LH tail lamp', 0.775, 0.500),
  _Spot('license_plate_back', 'Rear number plate', 0.500, 0.739),
  _Spot('bumper_back', 'Rear bumper', 0.230, 0.761),
  _Spot('exhaust', 'Exhaust tip', 0.760, 0.800),
];

const _fourRoof = <_Spot>[
  _Spot('roof_rail', 'Roof rails', 0.475, 0.196),
  _Spot('antenna', 'Roof antenna', 0.225, 0.326),
  _Spot('sunroof', 'Sunroof', 0.475, 0.413),
  _Spot('roof', 'Roof panel', 0.475, 0.598),
  _Spot('windshield_front', 'Windscreen', 0.625, 0.500),
  _Spot('hood', 'Bonnet', 0.840, 0.500),
  _Spot('windshield_back', 'Rear windscreen', 0.325, 0.500),
  _Spot('trunk', 'Boot lid', 0.175, 0.500),
  _Spot('mirror_right', 'RH wing mirror', 0.715, 0.174),
  _Spot('mirror_left', 'LH wing mirror', 0.715, 0.837),
];

const _fourInside = <String>[
  'Dashboard',
  'Steering wheel',
  'Instrument cluster',
  'Infotainment screen',
  'AC vents',
  'Gear lever',
  'Handbrake',
  'Driver seat',
  'Co-driver seat',
  'Rear seat',
  'Door trim',
  'Headliner',
  'Floor mat',
  'Boot floor',
  'Spare wheel',
  'Tool kit',
];

// --- two wheeler -----------------------------------------------------------

const _twoSide = <_Flank>[
  _Flank('license_plate_back', 'Number plate', 0.115, 0.600, sided: false),
  _Flank('tail_light', 'Tail lamp', 0.130, 0.410, sided: false),
  _Flank('rear_fender', 'Rear mudguard', 0.180, 0.520, sided: false),
  _Flank('wheel_back', 'Rear wheel', 0.230, 0.732, sided: false),
  _Flank('grab_rail', 'Grab rail', 0.265, 0.360),
  _Flank('chain_cover', 'Chain cover', 0.350, 0.760),
  _Flank('seat', 'Seat', 0.370, 0.393, sided: false),
  _Flank('side_panel', 'Side panel', 0.390, 0.518),
  _Flank('exhaust', 'Silencer', 0.480, 0.756),
  _Flank('foot_rest', 'Foot rest', 0.510, 0.660),
  _Flank('fuel_tank', 'Fuel tank', 0.560, 0.446, sided: false),
  _Flank('engine', 'Engine', 0.580, 0.625, sided: false),
  _Flank('mirror', 'Mirror', 0.650, 0.215),
  _Flank('handlebar', 'Handlebar', 0.700, 0.240),
  _Flank('disc_front', 'Front disc', 0.730, 0.672),
  _Flank('fork', 'Front fork', 0.755, 0.545),
  _Flank('head_light', 'Headlamp', 0.775, 0.304, sided: false),
  _Flank('wheel_front', 'Front wheel', 0.790, 0.732, sided: false),
  _Flank('front_fender', 'Front mudguard', 0.865, 0.500, sided: false),
];

const _twoFront = <_Spot>[
  _Spot('visor', 'Visor / cowl', 0.500, 0.224),
  _Spot('mirror_right', 'RH mirror', 0.067, 0.216),
  _Spot('mirror_left', 'LH mirror', 0.933, 0.216),
  _Spot('handlebar_right', 'RH handlebar', 0.192, 0.259),
  _Spot('handlebar_left', 'LH handlebar', 0.808, 0.259),
  _Spot('head_light', 'Headlamp', 0.500, 0.371),
  _Spot('front_fender', 'Front mudguard', 0.500, 0.569),
  _Spot('fork_right', 'RH fork', 0.385, 0.690),
  _Spot('fork_left', 'LH fork', 0.615, 0.690),
  _Spot('wheel_front', 'Front wheel', 0.500, 0.862),
];

const _twoRear = <_Spot>[
  _Spot('tail_light', 'Tail lamp', 0.500, 0.336),
  _Spot('grab_rail', 'Grab rail', 0.500, 0.466),
  _Spot('license_plate_back', 'Number plate', 0.500, 0.586),
  _Spot('exhaust', 'Silencer', 0.808, 0.655),
  _Spot('suspension_right', 'RH shock', 0.430, 0.700),
  _Spot('suspension_left', 'LH shock', 0.570, 0.700),
  _Spot('wheel_back', 'Rear wheel', 0.500, 0.853),
];

const _twoRoof = <_Spot>[
  _Spot('rear_fender', 'Rear mudguard', 0.145, 0.500),
  _Spot('seat', 'Seat', 0.440, 0.500),
  _Spot('fuel_tank', 'Fuel tank', 0.620, 0.500),
  _Spot('handlebar', 'Handlebar', 0.740, 0.500),
  _Spot('mirror_left', 'LH mirror', 0.740, 0.153),
  _Spot('mirror_right', 'RH mirror', 0.740, 0.847),
  _Spot('front_fender', 'Front mudguard', 0.835, 0.500),
];

const _twoInside = <String>[
  'Speedometer',
  'Ignition switch',
  'Switchgear',
  'Clutch lever',
  'Brake lever',
  'Horn',
  'Battery box',
  'Tool kit',
  'Key set',
];

// --- three wheeler ---------------------------------------------------------

const _threeSide = <_Flank>[
  _Flank('head_light', 'Headlamp', 0.155, 0.355, sided: false),
  _Flank('hood', 'Front cowl', 0.180, 0.480, sided: false),
  _Flank('front_fender', 'Front mudguard', 0.250, 0.575),
  _Flank('wheel_front', 'Front wheel', 0.280, 0.742, sided: false),
  _Flank('windshield_front', 'Windscreen', 0.300, 0.230, sided: false),
  _Flank('door_frame', 'Door frame', 0.400, 0.420),
  _Flank('roof', 'Canopy', 0.480, 0.165, sided: false),
  _Flank('rocker_panel', 'Foot board', 0.480, 0.640),
  _Flank('side_panel', 'Side panel', 0.520, 0.540),
  _Flank('passenger_cabin', 'Passenger cabin', 0.640, 0.420),
  _Flank('tail_light', 'Tail lamp', 0.760, 0.403),
  _Flank('rear_fender', 'Rear mudguard', 0.800, 0.580),
  _Flank('wheel_back', 'Rear wheel', 0.830, 0.758),
  _Flank('bumper_back', 'Rear guard', 0.880, 0.630, sided: false),
];

const _threeFront = <_Spot>[
  _Spot('roof', 'Canopy front', 0.500, 0.150),
  _Spot('windshield_front', 'Windscreen', 0.500, 0.274),
  _Spot('hood', 'Front cowl', 0.320, 0.400),
  _Spot('wiper_front', 'Wiper', 0.660, 0.380),
  _Spot('head_light', 'Headlamp', 0.500, 0.532),
  _Spot('indicator_right', 'RH indicator', 0.250, 0.540),
  _Spot('indicator_left', 'LH indicator', 0.750, 0.540),
  _Spot('front_fender', 'Front mudguard', 0.500, 0.680),
  _Spot('wheel_front', 'Front wheel', 0.500, 0.815),
];

const _threeRear = <_Spot>[
  _Spot('roof', 'Canopy rear', 0.500, 0.150),
  _Spot('windshield_back', 'Rear window', 0.500, 0.274),
  _Spot('tail_light_right', 'RH tail lamp', 0.223, 0.548),
  _Spot('tail_light_left', 'LH tail lamp', 0.777, 0.548),
  _Spot('license_plate_back', 'Number plate', 0.500, 0.565),
  _Spot('rear_panel', 'Rear panel', 0.500, 0.700),
  _Spot('wheel_back_right', 'RH rear wheel', 0.241, 0.839),
  _Spot('wheel_back_left', 'LH rear wheel', 0.759, 0.839),
  _Spot('bumper_back', 'Rear guard', 0.500, 0.760),
];

const _threeRoof = <_Spot>[
  _Spot('rear_panel', 'Rear panel', 0.130, 0.500),
  _Spot('side_panel_left', 'LH side', 0.400, 0.320),
  _Spot('side_panel_right', 'RH side', 0.400, 0.680),
  _Spot('roof', 'Canopy', 0.560, 0.500),
  _Spot('windshield_front', 'Windscreen', 0.760, 0.500),
  _Spot('head_light', 'Headlamp', 0.910, 0.500),
];

const _threeInside = <String>[
  'Driver seat',
  'Passenger seat',
  'Handlebar controls',
  'Meter console',
  'Floor board',
  'Roof lining',
  'Canopy cloth',
  'Mirror',
  'Fare meter',
];

// --- six wheeler -----------------------------------------------------------

const _sixSide = <_Flank>[
  _Flank('head_light', 'Headlamp', 0.085, 0.542),
  _Flank('bumper_front', 'Front bumper', 0.100, 0.646, sided: false),
  _Flank('grill_radiator', 'Radiator grille', 0.110, 0.406, sided: false),
  _Flank('mirror', 'Wing mirror', 0.135, 0.198),
  _Flank('wheel_front', 'Front wheel', 0.180, 0.813),
  _Flank('windshield_front', 'Windscreen', 0.240, 0.219, sided: false),
  _Flank('door_front', 'Cab door', 0.250, 0.490),
  _Flank('rocker_panel', 'Cab step', 0.300, 0.672),
  _Flank('fuel_tank', 'Fuel tank', 0.430, 0.813),
  _Flank('chassis', 'Chassis rail', 0.600, 0.780, sided: false),
  _Flank('cargo_rail', 'Top rail', 0.640, 0.167),
  _Flank('cargo_side_upper', 'Body side — upper', 0.640, 0.290),
  _Flank('cargo_side_lower', 'Body side — lower', 0.640, 0.542),
  _Flank('wheel_back', 'Rear wheel', 0.750, 0.813),
  _Flank('mud_flap', 'Mud flap', 0.845, 0.860),
  _Flank('tool_box', 'Tool box', 0.900, 0.771),
  _Flank('tail_light', 'Tail lamp', 0.950, 0.500),
];

const _sixFront = <_Spot>[
  _Spot('roof', 'Cab roof', 0.500, 0.115),
  _Spot('mirror_right', 'RH mirror', 0.050, 0.260),
  _Spot('mirror_left', 'LH mirror', 0.950, 0.260),
  _Spot('windshield_front', 'Windscreen', 0.500, 0.270),
  _Spot('wiper_front', 'Wipers', 0.290, 0.390),
  _Spot('grill_radiator', 'Radiator grille', 0.500, 0.567),
  _Spot('head_light_right', 'RH headlamp', 0.150, 0.577),
  _Spot('head_light_left', 'LH headlamp', 0.850, 0.577),
  _Spot('bumper_front', 'Front bumper', 0.250, 0.740),
  _Spot('license_plate_front', 'Number plate', 0.500, 0.740),
  _Spot('wheel_front_right', 'RH front wheel', 0.225, 0.904),
  _Spot('wheel_front_left', 'LH front wheel', 0.775, 0.904),
];

const _sixRear = <_Spot>[
  _Spot('hinge', 'Door hinges', 0.142, 0.192),
  _Spot('door_back_right', 'RH rear door', 0.270, 0.320),
  _Spot('sign_board', 'Sign board', 0.500, 0.365),
  _Spot('door_back_left', 'LH rear door', 0.730, 0.320),
  _Spot('tail_light_right', 'RH tail lamp', 0.175, 0.654),
  _Spot('license_plate_back', 'Number plate', 0.500, 0.654),
  _Spot('tail_light_left', 'LH tail lamp', 0.825, 0.654),
  _Spot('bumper_back', 'Rear guard', 0.500, 0.808),
  _Spot('wheel_back_right', 'RH rear wheel', 0.225, 0.894),
  _Spot('wheel_back_left', 'LH rear wheel', 0.775, 0.894),
];

const _sixRoof = <_Spot>[
  _Spot('mirror_right', 'RH mirror', 0.110, 0.083),
  _Spot('roof', 'Cab roof', 0.190, 0.500),
  _Spot('mirror_left', 'LH mirror', 0.110, 0.917),
  _Spot('head_board', 'Head board', 0.360, 0.500),
  _Spot('cargo_rail_right', 'RH top rail', 0.635, 0.230),
  _Spot('load_bed', 'Load bed', 0.635, 0.500),
  _Spot('cargo_rail_left', 'LH top rail', 0.635, 0.790),
  _Spot('tail_gate', 'Tail gate', 0.930, 0.500),
];

const _sixInside = <String>[
  'Dashboard',
  'Steering wheel',
  'Instrument cluster',
  'Driver seat',
  'Co-driver seat',
  'Sleeper berth',
  'Gear lever',
  'Cabin floor',
  'Door trim',
  'Roof lining',
];

// --- underbody -------------------------------------------------------------

const _fourUnder = <String>[
  'Engine guard',
  'Oil sump',
  'Silencer / exhaust',
  'Fuel tank',
  'Front suspension',
  'Rear suspension',
  'Axle / drive shaft',
  'Floor pan',
  'Side skirt underside',
  'Spare wheel well',
];

const _twoUnder = <String>[
  'Engine guard',
  'Silencer / exhaust',
  'Crankcase',
  'Main stand',
  'Side stand',
  'Chain cover',
  'Chassis frame',
];

const _threeUnder = <String>[
  'Engine guard',
  'Silencer / exhaust',
  'Fuel tank',
  'Rear axle',
  'Front suspension',
  'Chassis frame',
  'Floor pan',
];

const _sixUnder = <String>[
  'Chassis frame',
  'Fuel tank',
  'Silencer / exhaust',
  'Propeller shaft',
  'Front axle',
  'Rear axle',
  'Leaf springs',
  'Air tanks',
  'Battery box',
];

// --- assembly --------------------------------------------------------------

const Map<VehicleKind, List<_Flank>> _sides = {
  VehicleKind.twoWheeler: _twoSide,
  VehicleKind.threeWheeler: _threeSide,
  VehicleKind.fourWheeler: _fourSide,
  VehicleKind.sixWheeler: _sixSide,
};

const Map<VehicleKind, Map<VehicleArea, List<_Spot>>> _spots = {
  VehicleKind.twoWheeler: {
    VehicleArea.front: _twoFront,
    VehicleArea.rear: _twoRear,
    VehicleArea.roof: _twoRoof,
  },
  VehicleKind.threeWheeler: {
    VehicleArea.front: _threeFront,
    VehicleArea.rear: _threeRear,
    VehicleArea.roof: _threeRoof,
  },
  VehicleKind.fourWheeler: {
    VehicleArea.front: _fourFront,
    VehicleArea.rear: _fourRear,
    VehicleArea.roof: _fourRoof,
  },
  VehicleKind.sixWheeler: {
    VehicleArea.front: _sixFront,
    VehicleArea.rear: _sixRear,
    VehicleArea.roof: _sixRoof,
  },
};

const Map<VehicleKind, List<String>> _insides = {
  VehicleKind.twoWheeler: _twoInside,
  VehicleKind.threeWheeler: _threeInside,
  VehicleKind.fourWheeler: _fourInside,
  VehicleKind.sixWheeler: _sixInside,
};

const Map<VehicleKind, List<String>> _unders = {
  VehicleKind.twoWheeler: _twoUnder,
  VehicleKind.threeWheeler: _threeUnder,
  VehicleKind.fourWheeler: _fourUnder,
  VehicleKind.sixWheeler: _sixUnder,
};

/// Built once per body and face, because the flank lists are expanded into two
/// sets of parts and the picker asks for them on every rebuild.
final Map<String, List<VehiclePart>> _cache = {};

/// Every component on one face of one body.
List<VehiclePart> partsFor(VehicleKind kind, VehicleArea area) =>
    _cache.putIfAbsent('${kind.name}.${area.name}', () => _build(kind, area));

List<VehiclePart> _build(VehicleKind kind, VehicleArea area) {
  if (area.listed) {
    final names = area == VehicleArea.interior ? _insides : _unders;
    return [
      for (final n in names[kind] ?? const <String>[])
        VehiclePart(
          id: n.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '_'),
          name: n,
          area: area,
          x: 0.5,
          y: 0.5,
        ),
    ];
  }

  if (area == VehicleArea.driver || area == VehicleArea.passenger) {
    final right = area == VehicleArea.driver;
    return [
      for (final f in _sides[kind] ?? const <_Flank>[])
        VehiclePart(
          id: f.sided ? '${f.id}_${right ? 'right' : 'left'}' : f.id,
          name: f.name,
          area: area,
          x: f.x,
          y: f.y,
        ),
    ];
  }

  return [
    for (final s in _spots[kind]?[area] ?? const <_Spot>[])
      VehiclePart(id: s.id, name: s.name, area: area, x: s.x, y: s.y),
  ];
}

/// Every component on a body, for the search box — which looks across the
/// whole vehicle, not just the face on screen.
List<VehiclePart> allPartsFor(VehicleKind kind) => [
  for (final a in VehicleArea.values) ...partsFor(kind, a),
];

/// How a mark records the component it was pinned to, e.g.
/// `fourWheeler.driver.door_front_right`. The body and the face are in there
/// so a mark can be placed again without the catalog having to be searched.
String partId(VehicleKind kind, VehiclePart part) =>
    '${kind.name}.${part.area.name}.${part.id}';

/// The component a stored id names, or null if the catalog no longer has it.
VehiclePart? partOf(String id) {
  final bits = id.split('.');
  if (bits.length != 3) return null;
  VehicleKind? kind;
  for (final k in VehicleKind.values) {
    if (k.name == bits[0]) kind = k;
  }
  VehicleArea? area;
  for (final a in VehicleArea.values) {
    if (a.name == bits[1]) area = a;
  }
  if (kind == null || area == null) return null;
  for (final p in partsFor(kind, area)) {
    if (p.id == bits[2]) return p;
  }
  return null;
}

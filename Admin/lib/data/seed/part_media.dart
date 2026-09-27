import '../models/enums.dart';

/// Photographs for the billing catalogue, fetched over the network.
///
/// ## Why URLs and not assets
///
/// [VehicleMedia] bundles its photography, because a vehicle's picture is on
/// the job card the customer is handed and has to be there on a dead phone
/// signal. A part thumbnail is not that. It is a recognition aid on a picker
/// — the storeman is scanning for the shape of a brake shoe, not reading the
/// picture — so it can arrive late, and it can fail to arrive at all. Every
/// surface that shows one degrades to a tinted icon, and nothing about the
/// bill changes when it does.
///
/// That buys the catalogue something a bundle cannot: a new part priced at
/// the counter this afternoon gets a photograph the moment it is saved, with
/// no asset to ship and no release to wait for.
///
/// ## Why a keyword map and not a column per row
///
/// A master row stores what the counter typed — `Front Disc Pad`, `Rear
/// Brake Liner` — and nothing about imagery, exactly as a vehicle stores no
/// picture. The photograph is *derived*, every time, from the words in the
/// name. Two consequences, both wanted: a part typed in five years ago picks
/// up a picture the day a keyword for it is added here, and nobody at the
/// counter is ever asked to find a photograph before they can save a part.
///
/// The resolution is deliberately coarse. There is no photograph of a
/// "Yamaha FZ front brake liner" and there never will be; there is a
/// photograph of a brake shoe, and that is what the eye needs. Families, not
/// SKUs.
///
/// ## Provenance
///
/// Every file is from Wikimedia Commons and is public domain or CC-licensed.
/// The CC BY and CC BY-SA ones make naming the author a *condition* of use,
/// which is why [credits] exists and why the credits screen reads it — the
/// same arrangement the bundled vehicle photography is under. Adding a row
/// to [_photos] without its author and licence is a licence breach.
class PartMedia {
  const PartMedia._();

  /// One photograph, with everything the credits screen needs to name it.
  static const Map<String, PartPhoto> _photos = {
    'filter': (
      url:
          'https://upload.wikimedia.org/wikipedia/commons/thumb/7/75/Ram_air_cleaner.jpg/500px-Ram_air_cleaner.jpg',
      subject: 'Air filter housing',
      author: 'Enginedesigner',
      licence: 'Public domain',
      source: 'https://commons.wikimedia.org/wiki/File:Ram_air_cleaner.jpg',
    ),
    'brakepad': (
      url:
          'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b0/Disc_brake_pads.JPG/500px-Disc_brake_pads.JPG',
      subject: 'Disc brake pads',
      author: 'PetarM',
      licence: 'CC BY-SA 3.0',
      source: 'https://commons.wikimedia.org/wiki/File:Disc_brake_pads.JPG',
    ),
    'brakeshoe': (
      url:
          'https://upload.wikimedia.org/wikipedia/commons/thumb/2/28/BRAKE_SHOE.jpg/500px-BRAKE_SHOE.jpg',
      subject: 'Drum brake shoe',
      author: 'Nimal Kumar',
      licence: 'CC BY-SA 3.0',
      source: 'https://commons.wikimedia.org/wiki/File:BRAKE_SHOE.jpg',
    ),
    'plug': (
      url:
          'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b9/Spark_plug.jpg/500px-Spark_plug.jpg',
      subject: 'Spark plug',
      author: 'Unattributed',
      licence: 'Public domain',
      source: 'https://commons.wikimedia.org/wiki/File:Spark_plug.jpg',
    ),
    'bearing': (
      url:
          'https://upload.wikimedia.org/wikipedia/commons/thumb/2/2d/Ball_bearing.jpg/500px-Ball_bearing.jpg',
      subject: 'Ball bearing',
      author: 'Solaris2006',
      licence: 'CC BY-SA 3.0',
      source: 'https://commons.wikimedia.org/wiki/File:Ball_bearing.jpg',
    ),
    'chain': (
      url:
          'https://upload.wikimedia.org/wikipedia/commons/thumb/2/2d/Motorcycle_chain.jpg/500px-Motorcycle_chain.jpg',
      subject: 'Drive chain',
      author: 'sutulo',
      licence: 'CC0',
      source: 'https://commons.wikimedia.org/wiki/File:Motorcycle_chain.jpg',
    ),
    'battery': (
      url:
          'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a4/Lead-acid_battery_for_motorcycle.jpg/500px-Lead-acid_battery_for_motorcycle.jpg',
      subject: 'Battery',
      author: 'Cjp24',
      licence: 'CC BY-SA 4.0',
      source:
          'https://commons.wikimedia.org/wiki/File:Lead-acid_battery_for_motorcycle.jpg',
    ),
    'tyre': (
      url:
          'https://upload.wikimedia.org/wikipedia/commons/thumb/2/20/Motorcycle_tyre_stack.jpg/500px-Motorcycle_tyre_stack.jpg',
      subject: 'Tyres',
      author: 'Robert',
      licence: 'CC BY 2.0',
      source:
          'https://commons.wikimedia.org/wiki/File:Motorcycle_tyre_stack.jpg',
    ),
    'clutch': (
      url:
          'https://upload.wikimedia.org/wikipedia/commons/thumb/a/af/Clutch_disc.JPG/500px-Clutch_disc.JPG',
      subject: 'Clutch plate',
      author: '100yen',
      licence: 'CC BY-SA 3.0',
      source: 'https://commons.wikimedia.org/wiki/File:Clutch_disc.JPG',
    ),
    'piston': (
      url:
          'https://upload.wikimedia.org/wikipedia/commons/thumb/1/12/47mm_piston_rings.jpg/500px-47mm_piston_rings.jpg',
      subject: 'Piston rings',
      author: 'Kallemax',
      licence: 'Public domain',
      source: 'https://commons.wikimedia.org/wiki/File:47mm_piston_rings.jpg',
    ),
    'carb': (
      url:
          'https://upload.wikimedia.org/wikipedia/commons/f/fa/Amal_type_276_carburettor_fitted_to_a1951_BSA_B31_350cc.jpg',
      subject: 'Carburettor',
      author: 'Yesterdays Antique Motorcycles',
      licence: 'CC BY-SA 4.0',
      source:
          'https://commons.wikimedia.org/wiki/File:Amal_type_276_carburettor_fitted_to_a1951_BSA_B31_350cc.jpg',
    ),
    'cable': (
      url:
          'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a7/Bowden_cable_throttle.jpg/500px-Bowden_cable_throttle.jpg',
      subject: 'Throttle cable',
      author: 'Scott Ehardt',
      licence: 'Public domain',
      source:
          'https://commons.wikimedia.org/wiki/File:Bowden_cable_throttle.jpg',
    ),
    'bulb': (
      url:
          'https://upload.wikimedia.org/wikipedia/commons/thumb/b/bf/H4_Philips_Premium_used.JPG/500px-H4_Philips_Premium_used.JPG',
      subject: 'Headlamp bulb',
      author: 'MattiPaavola',
      licence: 'CC BY-SA 3.0',
      source:
          'https://commons.wikimedia.org/wiki/File:H4_Philips_Premium_used.JPG',
    ),
    'forks': (
      url:
          'https://upload.wikimedia.org/wikipedia/commons/8/8b/Bmw-telescopic.jpg',
      subject: 'Telescopic fork',
      author: 'Unattributed',
      licence: 'Attribution',
      source: 'https://commons.wikimedia.org/wiki/File:Bmw-telescopic.jpg',
    ),
    'engineoil': (
      url:
          'https://upload.wikimedia.org/wikipedia/commons/thumb/b/bb/Mobil_1_motor_oil.jpg/500px-Mobil_1_motor_oil.jpg',
      subject: 'Engine oil',
      author: 'Interiot',
      licence: 'Public domain',
      source: 'https://commons.wikimedia.org/wiki/File:Mobil_1_motor_oil.jpg',
    ),
    'canister': (
      url:
          'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4c/Caltex_%26_Texaco_canisters.JPG/500px-Caltex_%26_Texaco_canisters.JPG',
      subject: 'Lubricant canisters',
      author: 'AlfvanBeem',
      licence: 'CC0',
      source:
          'https://commons.wikimedia.org/wiki/File:Caltex_%26_Texaco_canisters.JPG',
    ),
    'spray': (
      url:
          'https://upload.wikimedia.org/wikipedia/commons/thumb/7/7f/Delicia_Silicon_Spray.jpg/500px-Delicia_Silicon_Spray.jpg',
      subject: 'Lubricant spray',
      author: 'Wolfemood',
      licence: 'CC BY-SA 4.0',
      source:
          'https://commons.wikimedia.org/wiki/File:Delicia_Silicon_Spray.jpg',
    ),
    'grease': (
      url:
          'https://upload.wikimedia.org/wikipedia/commons/thumb/6/60/Ca_1990_tube_of_Tribol_3030_2_high_performance_grease_by_Tribol_GmbH_ICI_Moenchengladbach_Germany.jpg/500px-Ca_1990_tube_of_Tribol_3030_2_high_performance_grease_by_Tribol_GmbH_ICI_Moenchengladbach_Germany.jpg',
      subject: 'Grease',
      author: 'R. Henrik Nilsson',
      licence: 'CC BY 4.0',
      source:
          'https://commons.wikimedia.org/wiki/File:Ca_1990_tube_of_Tribol_3030_2_high_performance_grease_by_Tribol_GmbH_ICI_Moenchengladbach_Germany.jpg',
    ),
    'workshop': (
      url:
          'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d5/Mechanic_repairs_motorcycle_while_enjoying_a_sunny_afternoon.jpg/500px-Mechanic_repairs_motorcycle_while_enjoying_a_sunny_afternoon.jpg',
      subject: 'Mechanic at work',
      author: 'Shixart1985',
      licence: 'CC BY 2.0',
      source:
          'https://commons.wikimedia.org/wiki/File:Mechanic_repairs_motorcycle_while_enjoying_a_sunny_afternoon.jpg',
    ),
    'bay': (
      url:
          'https://upload.wikimedia.org/wikipedia/commons/thumb/7/73/Une_all%C3%A9e_de_garage_m%C3%A9canicien.jpg/500px-Une_all%C3%A9e_de_garage_m%C3%A9canicien.jpg',
      subject: 'Workshop bay',
      author: 'Babacar Dioum',
      licence: 'CC BY-SA 4.0',
      source:
          'https://commons.wikimedia.org/wiki/File:Une_all%C3%A9e_de_garage_m%C3%A9canicien.jpg',
    ),
  };

  /// Keyword -> photograph, tried in order.
  ///
  /// Ordered, not a map, and the order is the whole design: `disc pad` has to
  /// be tested before `pad`, and `fork oil` before `oil`, or a front disc pad
  /// gets the drum shoe and a fork oil gets the engine oil bottle. New
  /// keywords go beside the family they belong to, not at the end.
  static const List<(String, String)> _keywords = [
    // brakes — the specific shape first, then the generic word
    ('disc pad', 'brakepad'),
    ('disc brake', 'brakepad'),
    ('brake pad', 'brakepad'),
    ('brake liner', 'brakeshoe'),
    ('brake shoe', 'brakeshoe'),
    ('drum rubber', 'brakeshoe'),
    ('brake', 'brakeshoe'),

    // lubricants — every one of these is a bottle, so they run before the
    // hardware words that share a root ('oil seal', 'oil filter')
    ('oil seal', 'piston'),
    ('oil filter', 'filter'),
    ('fork oil', 'forks'),
    ('gear box oil', 'canister'),
    ('gear oil', 'canister'),
    ('engine oil', 'engineoil'),
    ('motor oil', 'engineoil'),
    ('synthetic', 'engineoil'),
    ('coolant', 'canister'),
    ('brake fluid', 'canister'),
    ('chain lube', 'spray'),
    ('cleaner', 'spray'),
    ('spray', 'spray'),
    ('grease', 'grease'),
    ('lube', 'canister'),

    // hardware
    ('air filter', 'filter'),
    ('filter', 'filter'),
    ('spark plug', 'plug'),
    ('plug', 'plug'),
    ('bearing', 'bearing'),
    ('cone set', 'bearing'),
    ('bush', 'bearing'),
    ('sprocket', 'chain'),
    ('chain', 'chain'),
    ('battery', 'battery'),
    ('tyre', 'tyre'),
    ('tube', 'tyre'),
    ('clutch', 'clutch'),
    ('piston', 'piston'),
    ('ring', 'piston'),
    ('seal', 'piston'),
    ('carburat', 'carb'),
    ('carburet', 'carb'),
    ('throttle', 'carb'),
    ('cable', 'cable'),
    ('wire', 'cable'),
    ('bulb', 'bulb'),
    ('lamp', 'bulb'),
    ('light', 'bulb'),
    ('fork', 'forks'),
    ('suspension', 'forks'),
    ('shock', 'forks'),
  ];

  /// The photograph for a catalogue row, or null where nothing in the name
  /// is recognised and the caller should fall back to an icon.
  ///
  /// Labour never resolves to a part photograph: a "Brake Liner Fitting
  /// Labour" row is an hour of somebody's time, and showing it a picture of a
  /// brake shoe would say the workshop is billing for the part.
  static String? urlFor(LineKind kind, String name) {
    if (kind == LineKind.job) return null;
    final n = name.toLowerCase();
    for (final (word, key) in _keywords) {
      if (n.contains(word)) return _photos[key]!.url;
    }
    return null;
  }

  /// Scene-setting photography for the billing screens themselves, keyed by
  /// kind. Unlike [urlFor] this always resolves — it is decoration on a
  /// masthead, and a masthead with a hole in it looks broken.
  static String mastheadFor(LineKind kind) => switch (kind) {
    LineKind.job => _photos['workshop']!.url,
    LineKind.spare => _photos['bearing']!.url,
    LineKind.lube => _photos['canister']!.url,
  };

  /// Everything shown, with who it belongs to. Read by the credits screen.
  static List<PartPhoto> get credits => _photos.values.toList();
}

/// One catalogue photograph and its attribution.
typedef PartPhoto = ({
  String url,
  String subject,
  String author,
  String licence,
  String source,
});

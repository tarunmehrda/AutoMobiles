import '../models/enums.dart';

/// Which picture a vehicle gets, and where the pictures came from.
///
/// ## The rule
///
/// **Every vehicle gets a photograph.** There is no state in which a job card
/// shows a line drawing where a picture should be. The lookup falls back in
/// one direction only, and each step is still a photograph:
///
/// 1. a photograph of that exact model, where one is bundled — a Swift shows
///    a Swift;
/// 2. failing that, a photograph of its body — a Zen shows a hatchback, a
///    Splendor shows a motorcycle, an Activa shows a scooter, a Bajaj RE
///    shows an auto, a Tata 407 shows a truck.
///
/// The drawings in `VehicleArt` are still there, but only as the last resort
/// for a vehicle whose make and model are both blank — a card opened on a
/// plate alone, before anything has been typed.
///
/// ## Provenance
///
/// * **Model photography** (`assets/models`) and **marque logos**
///   (`assets/brands`, 18 files): the same sets the customer app ships,
///   copied across rather than re-sourced, so a Swift is the same Swift on
///   both sides of the counter. Photography from Unsplash; logos from the
///   Simple Icons set (CC0), with Mercedes-Benz as a raster fallback because
///   the set has no vector for it.
///
/// * **Body photography** (`assets/bodies`, 10 files). Five are the customer
///   app's own body shots — hatchback, sedan, SUV, luxury, EV. Five were
///   sourced for this app because nothing over there covers what a workshop
///   sees beyond cars: `muv`, `motorcycle`, `scooter`, `auto` and `truck`.
///   Those five are CC0 or public domain, via Openverse; the credits are in
///   `assets/bodies/CREDITS.md`. All ten are normalised to 480x310, the same
///   frame as the model photography, so nothing jumps when the fallback
///   takes over.
///
/// ## Why lookup rather than a column
///
/// A vehicle record stores what the counter typed — `Maruti Suzuki`, `Swift`,
/// `VXi` — and nothing about imagery. Pictures are therefore *derived*, every
/// time. That is deliberate: a vehicle saved two years ago starts showing its
/// own photograph the day one is dropped into `assets/models/`, with no
/// migration and no backfill.
class VehicleMedia {
  const VehicleMedia._();

  static const String _models = 'assets/models';
  static const String _brands = 'assets/brands';
  static const String _bodies = 'assets/bodies';

  // --- marques -------------------------------------------------------------

  /// Catalogue make -> the logo file for it. A make with no entry simply
  /// shows no logo; nothing downstream has to handle a missing file.
  static const Map<String, String> _logos = {
    'Maruti Suzuki': '$_brands/maruti.svg',
    'Suzuki': '$_brands/maruti.svg',
    'Hyundai': '$_brands/hyundai.svg',
    'Tata': '$_brands/tata.svg',
    'Tata Motors': '$_brands/tata.svg',
    'Mahindra': '$_brands/mahindra.svg',
    'Mahindra 2 Wheelers': '$_brands/mahindra.svg',
    'Honda': '$_brands/honda.svg',
    'Toyota': '$_brands/toyota.svg',
    'Kia': '$_brands/kia.svg',
    'MG': '$_brands/mg.svg',
    'Volkswagen': '$_brands/vw.svg',
    'Skoda': '$_brands/skoda.svg',
    'Renault': '$_brands/renault.svg',
    'Nissan': '$_brands/nissan.svg',
    'Ford': '$_brands/ford.svg',
    'Jeep': '$_brands/jeep.svg',
    'BMW': '$_brands/bmw.svg',
    'Mercedes-Benz': '$_brands/mercedes.png',
    'Audi': '$_brands/audi.svg',
    'Tesla': '$_brands/tesla.svg',
  };

  /// The marque's mark, or null where none is bundled.
  static String? logoFor(String? brand) =>
      brand == null ? null : _logos[brand.trim()];

  static bool isVector(String path) => path.endsWith('.svg');

  // --- model photography ---------------------------------------------------

  /// Model ids with a file of their own in `assets/models/`.
  ///
  /// Drop `<id>.jpg` in beside the others, add the id here, and that model
  /// starts showing its own photograph instead of its body's. Nothing else
  /// changes — and nothing breaks in the meantime, because the body shot is
  /// already a photograph.
  static const Set<String> _exact = {
    '125duke',
    '200duke',
    '2seriesgrancoupe',
    '390adventure',
    '390duke',
    '3series',
    '42',
    '42bobber',
    '5series',
    '7series',
    '800',
    'a4',
    'a6',
    'a8l',
    'accent',
    'access125',
    'accord',
    'activa6g',
    'aerox155',
    'alcazar',
    'alto',
    'alto800',
    'altok10',
    'altroz',
    'amaze',
    'ambassador',
    'ameo',
    'apachertr160',
    'apachertr180',
    'apachertr200',
    'apecity',
    'aria',
    'aspire',
    'astar',
    'astor',
    'astra',
    'atto3',
    'aura',
    'avenger160',
    'avenger220',
    'aveo',
    'baleno',
    'balenosedan',
    'basalt',
    'be6',
    'beat',
    'bolero',
    'bolt',
    'brezza',
    'brio',
    'brv',
    'bullet350',
    'burgmanstreet',
    'c3',
    'c3aircross',
    'c40recharge',
    'c5aircross',
    'camry',
    'captiva',
    'captur',
    'carens',
    'carnival',
    'cayenne',
    'cb350',
    'cbhornet160r',
    'cclass',
    'celerio',
    'centuro',
    'chetak',
    'ciaz',
    'city',
    'civic',
    'classic350',
    'cometev',
    'compass',
    'contessa',
    'continentalgt650',
    'cooper',
    'corolla',
    'corollaaltis',
    'corsa',
    'countryman',
    'creta',
    'cretaelectric',
    'cruze',
    'crv',
    'ct100',
    'curvv',
    'curvvev',
    'defender',
    'dio',
    'discovery',
    'discoverysport',
    'dmaxvcross',
    'dominar400',
    'duster',
    'dzire',
    'e2oplus',
    'eclass',
    'ecosport',
    'eeco',
    'elantra',
    'elevate',
    'emax7',
    'eon',
    'eqs',
    'ertiga',
    'es',
    'esteem',
    'etios',
    'etiosliva',
    'etrongt',
    'ev6',
    'ev9',
    'evalia',
    'exter',
    'fabia',
    'fiesta',
    'figo',
    'fluence',
    'fortuner',
    'fpace',
    'freestyle',
    'fronx',
    'fusion',
    'fzs',
    'fzx',
    'getz',
    'gixxer',
    'gixxersf',
    'gla',
    'glanza',
    'glc',
    'gle',
    'gls',
    'go',
    'goldstar650',
    'grandcherokee',
    'grandi10nios',
    'grandvitara',
    'guerrilla450',
    'gurkha',
    'gypsy',
    'harrier',
    'hayate',
    'hector',
    'hexa',
    'hf100',
    'himalayan',
    'hunk',
    'hycross',
    'i10',
    'i20',
    'i4',
    'ignis',
    'ikon',
    'indica',
    'indicavista',
    'indigo',
    'indigoecs',
    'innovacrysta',
    'interceptor650',
    'intruder',
    'invicto',
    'ioniq5',
    'iron883',
    'ix1',
    'jawa350',
    'jazz',
    'jetta',
    'jupiter',
    'karizma',
    'kicks',
    'kizashi',
    'kodiaq',
    'koleos',
    'konaelectric',
    'kushaq',
    'kuv100nxt',
    'kwid',
    'kylaq',
    'landcruiser',
    'linea',
    'lm',
    'macan',
    'magnite',
    'manza',
    'marazzo',
    'maximac',
    'meteor350',
    'micra',
    'mobilio',
    'model3',
    'modely',
    'mt15',
    'mustang',
    'mux',
    'nano',
    'nexon',
    'nexonev',
    'ninja300',
    'ninja650',
    'ntorq125',
    'nx',
    'octavia',
    'omni',
    'optra',
    'padmini',
    'palio',
    'panamera',
    'passat',
    'passionpro',
    'perak',
    'platina110',
    'pleasure',
    'polo',
    'pulsar125',
    'pulsar150',
    'pulsar180',
    'pulse',
    'punch',
    'punchev',
    'punto',
    'q3',
    'q5',
    'q7',
    'q8',
    'qualis',
    'quanto',
    'r15',
    'radeon',
    'raider125',
    'rangerover',
    'rangeroverevoque',
    'rangeroversport',
    'rangerovervelar',
    'rapid',
    'rc200',
    'recompact',
    'redigo',
    'rio',
    'ritz',
    'rumion',
    'rx',
    's1pro',
    's60',
    'safari',
    'safaristorme',
    'sail',
    'saluto',
    'santafe',
    'santro',
    'santroxing',
    'scala',
    'sclass',
    'scorpio',
    'scorpion',
    'scrambler400x',
    'scross',
    'seal',
    'seltos',
    'siena',
    'slavia',
    'sonata',
    'sonet',
    'sp125',
    'spark',
    'speed400',
    'splendorismart',
    'splendorplus',
    'spresso',
    'sr125',
    'star',
    'sumo',
    'sunny',
    'superb',
    'supercarry',
    'supermeteor650',
    'swift',
    'sx4',
    'syros',
    'taigun',
    'tavera',
    'taycan',
    'terrano',
    'thar',
    'tharroxx',
    'thunderbird',
    'tiago',
    'tiagoev',
    'tigor',
    'tiguan',
    'trailblazer',
    'traveller',
    'traxcruiser',
    'triber',
    'tucson',
    'tuv300',
    'uno',
    'urbancruiser',
    'urbancruiserhyryder',
    'urbancruisertaisor',
    'vellfire',
    'vento',
    'venture',
    'venue',
    'verito',
    'veritovibe',
    'verna',
    'vespa',
    'virtus',
    'vulcans',
    'w175',
    'wagonr',
    'wego',
    'wrangler',
    'wrv',
    'x1',
    'x3',
    'x5',
    'x7',
    'xc40',
    'xc60',
    'xc90',
    'xcent',
    'xe',
    'xev9e',
    'xf',
    'xl6',
    'xpulse200',
    'xtrail',
    'xuv300',
    'xuv3xo',
    'xuv500',
    'xuv700',
    'xylo',
    'yaris',
    'yeti',
    'z650',
    'zen',
    'zenestilo',
    'zest',
    'zsev',
  };

  /// Catalogue model -> photo id, for the ones [_id] cannot reach on its own.
  ///
  /// Two cases only. A facelift or a powertrain variant that is the same
  /// sheet metal in the bay (`Punch EV` is a `Punch`), and a name the
  /// photograph was filed under differently (`Innova Crysta` is `innova`).
  /// Anything that needs a genuinely different picture is not listed here —
  /// it gets its body's photograph until a file exists for it.
  static const Map<String, String> _aliases = {
    'innova hycross': 'hycross',
    'scorpio classic': 'scorpion',
    'bolero neo': 'bolero',
    'harrier ev': 'harrier',
    'hector plus': 'hector',
    'xuv400 ev': 'xuv300',
  };

  /// `Alto K10` -> `altok10`, `C-Class` -> `cclass`, `3 Series` -> `3series`.
  ///
  /// Everything that is not a letter or a digit goes, which is what keeps the
  /// alias table above as short as it is: spacing, hyphens and case are all
  /// that separate most catalogue names from their file.
  static String _id(String model) =>
      model.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

  /// A photograph of this exact model, or null when none is bundled.
  ///
  /// Callers normally want [photoFor], which never returns null. This is for
  /// the few places that need to know whether the picture is of the real
  /// thing — the model picker marks those rows.
  static String? exactPhotoFor(String? model) {
    final raw = model?.trim().toLowerCase() ?? '';
    if (raw.isEmpty) return null;
    // The model's own file first. An alias is a deliberate second best — it
    // says "this is the same sheet metal as that one" — so the day a
    // `Punch EV` photograph lands, it must win over the `Punch` it was
    // borrowing, without anyone remembering to delete the alias.
    final own = _id(raw);
    if (_exact.contains(own)) return '$_models/$own.jpg';
    final alias = _aliases[raw];
    return alias != null && _exact.contains(alias)
        ? '$_models/$alias.jpg'
        : null;
  }

  // --- body photography ----------------------------------------------------

  /// Marques whose every car is a luxury car, so the body shot is the
  /// luxury one rather than a hatchback that happens to share its outline.
  static const Set<String> _luxuryMakes = {
    'BMW',
    'Mercedes-Benz',
    'Audi',
    'Volvo',
    'Land Rover',
    'Jaguar',
    'Lexus',
    'Porsche',
    'MINI',
    'Tesla',
  };

  static const Set<String> _suv = {
    'brezza',
    'grandvitara',
    'gypsy',
    'jimny',
    'scross',
    'fronx',
    'alcazar',
    'creta',
    'exter',
    'santafe',
    'tucson',
    'venue',
    'curvv',
    'harrier',
    'nexon',
    'punch',
    'safari',
    'safaristorme',
    'alturasg4',
    'bolero',
    'boleroneo',
    'kuv100nxt',
    'nuvosport',
    'quanto',
    'scorpio',
    'scorpioclassic',
    'scorpion',
    'tuv300',
    'thar',
    'tharroxx',
    'xuv3xo',
    'xuv500',
    'xuv700',
    'brv',
    'crv',
    'elevate',
    'wrv',
    'fortuner',
    'landcruiser',
    'urbancruiser',
    'urbancruiserhyryder',
    'urbancruisertaisor',
    'seltos',
    'sonet',
    'syros',
    'astor',
    'gloster',
    'hector',
    'hectorplus',
    'taigun',
    'tiguan',
    'kodiaq',
    'kushaq',
    'kylaq',
    'yeti',
    'captur',
    'duster',
    'kiger',
    'koleos',
    'kicks',
    'magnite',
    'terrano',
    'xtrail',
    'basalt',
    'c3aircross',
    'c5aircross',
    'compass',
    'grandcherokee',
    'meridian',
    'wrangler',
    'dmaxvcross',
    'mux',
    'gurkha',
    'captiva',
    'trailblazer',
    'ecosport',
    'endeavour',
    'rio',
  };

  static const Set<String> _sedan = {
    'balenosedan',
    'ciaz',
    'dzire',
    'esteem',
    'kizashi',
    'sx4',
    'accent',
    'aura',
    'elantra',
    'sonata',
    'verna',
    'xcent',
    'indigo',
    'indigoecs',
    'manza',
    'tigor',
    'zest',
    'logan',
    'verito',
    'veritovibe',
    'accord',
    'amaze',
    'city',
    'civic',
    'camry',
    'corolla',
    'corollaaltis',
    'etios',
    'yaris',
    'ameo',
    'jetta',
    'passat',
    'vento',
    'virtus',
    'laura',
    'octavia',
    'rapid',
    'slavia',
    'superb',
    'fluence',
    'scala',
    'sunny',
    'aveo',
    'cruze',
    'optra',
    'sail',
    'aspire',
    'fiesta',
    'ikon',
    'linea',
    'siena',
    'ambassador',
    'contessa',
    'padmini',
  };

  static const Set<String> _muv = {
    'eeco',
    'ertiga',
    'invicto',
    'omni',
    'versa',
    'xl6',
    'aria',
    'hexa',
    'sumo',
    'sumogold',
    'venture',
    'marazzo',
    'xylo',
    'mobilio',
    'innovacrysta',
    'innovahycross',
    'qualis',
    'rumion',
    'vellfire',
    'carens',
    'carnival',
    'lodgy',
    'triber',
    'evalia',
    'enjoy',
    'tavera',
    'traveller',
    'go',
  };

  /// Anything whose body shot should be the EV one — a mass-market electric
  /// whose silhouette is nothing like the petrol car it is named after, or a
  /// nameplate that only ever existed as an EV.
  static const Set<String> _ev = {
    'cretaelectric',
    'ioniq5',
    'konaelectric',
    'curvvev',
    'harrierev',
    'nexonev',
    'punchev',
    'tiagoev',
    'tigorev',
    'be6',
    'xev9e',
    'xuv400ev',
    'e2oplus',
    'ev6',
    'ev9',
    'cometev',
    'windsorev',
    'zsev',
    'ec3',
    'atto3',
    'seal',
    'emax7',
  };

  /// Two-wheelers that are scooters rather than motorcycles. The two look
  /// nothing alike and a workshop sorts its bays by which is which.
  static const Set<String> _scooters = {
    'destini125',
    'maestroedge',
    'pleasure',
    'xoom',
    'activa110',
    'activa125',
    'activa6g',
    'aviator',
    'dio',
    'grazia',
    'chetak',
    'jupiter',
    'jupiter125',
    'ntorq125',
    'scootypepplus',
    'scootyzest',
    'wego',
    'iqube',
    'xl100',
    'aerox155',
    'fascino125',
    'rayzr',
    'access125',
    'avenis',
    'burgmanstreet',
    'gusto',
  };

  /// Marques here that only sell scooters.
  static const Set<String> _scooterMakes = {
    'Vespa',
    'Ather',
    'Ola Electric',
    'Ampere',
    'Okinawa',
    'Aprilia',
    'Kinetic Green',
  };

  /// The photograph of the body, given everything known about the vehicle.
  ///
  /// Never null, and never a car standing in for a bike: the body style is
  /// decided by [shape] first, and only a four-wheeler goes on to be sorted
  /// into hatchback, sedan, SUV and the rest.
  static String bodyPhotoFor(String? brand, String? model, VehicleShape shape) {
    final make = brand?.trim() ?? '';
    final id = _id(model?.trim() ?? '');

    switch (shape) {
      case VehicleShape.twoWheeler:
        final scooter = _scooterMakes.contains(make) || _scooters.contains(id);
        return '$_bodies/${scooter ? 'scooter' : 'motorcycle'}.jpg';
      case VehicleShape.threeWheeler:
        return '$_bodies/auto.jpg';
      case VehicleShape.sixWheeler:
        return '$_bodies/truck.jpg';
      case VehicleShape.fourWheeler:
        if (_ev.contains(id)) return '$_bodies/ev.jpg';
        if (_luxuryMakes.contains(make)) return '$_bodies/luxury.jpg';
        if (_suv.contains(id)) return '$_bodies/suv.jpg';
        if (_muv.contains(id)) return '$_bodies/muv.jpg';
        if (_sedan.contains(id)) return '$_bodies/sedan.jpg';
        // The default is the commonest thing on an Indian forecourt, and the
        // one a name gives away least about.
        return '$_bodies/hatchback.jpg';
    }
  }

  /// The picture for a vehicle: its own photograph if there is one, its
  /// body's photograph otherwise.
  ///
  /// Returns null only when there is nothing to go on at all — no make and no
  /// model — which is the one case where the caller should draw instead.
  static String? photoFor(String? brand, String? model, VehicleShape shape) {
    final exact = exactPhotoFor(model);
    if (exact != null) return exact;
    final hasSomething =
        (brand?.trim().isNotEmpty ?? false) ||
        (model?.trim().isNotEmpty ?? false);
    return hasSomething ? bodyPhotoFor(brand, model, shape) : null;
  }

  // --- body style ----------------------------------------------------------

  /// Marques that only sell two-wheelers here.
  ///
  /// Honda and Suzuki are absent on purpose. Both sell bikes *and* cars in
  /// India, so the make alone cannot settle it, and the counter's own pick on
  /// the job card is what decides — guessing `bike` from `Honda` would put a
  /// motorcycle on the header of every City that comes in.
  static const Set<String> _twoWheelerMakes = {
    'Hero',
    'Hero MotoCorp',
    'Bajaj',
    'TVS',
    'Yamaha',
    'Royal Enfield',
    'KTM',
    'Jawa',
    'Ola',
    'Ola Electric',
    'Ather',
    'Vespa',
    'Aprilia',
    'Harley-Davidson',
    'Triumph',
    'BSA',
    'Yezdi',
    'Kawasaki',
    'Ducati',
    'Revolt',
    'Okinawa',
    'Ampere',
    'LML',
    'Mahindra 2 Wheelers',
  };

  /// Marques whose Indian range is overwhelmingly three-wheelers.
  static const Set<String> _threeWheelerMakes = {
    'Piaggio',
    'Atul',
    'Atul Auto',
    'YC Electric',
    'Saera',
    'Kinetic Green',
  };

  /// Marques that are here for trucks and buses.
  static const Set<String> _sixWheelerMakes = {
    'Ashok Leyland',
    'Eicher',
    'BharatBenz',
    'SML Isuzu',
    'Man Trucks',
    'Tata Motors',
    'Volvo Trucks',
    'Scania',
  };

  /// The best guess at what a saved vehicle physically is.
  ///
  /// Used where the counter never got to say — a vehicle pulled out of
  /// history from before the body style was recorded. The job card form asks
  /// outright and stores the answer, so this is only ever the fallback, and
  /// it is written to be wrong in the safe direction: anything it does not
  /// recognise is a car, which is what the overwhelming majority of those
  /// records are.
  static VehicleShape shapeFor(String? brand) {
    final make = brand?.trim() ?? '';
    if (make.isEmpty) return VehicleShape.fourWheeler;
    if (_twoWheelerMakes.contains(make)) return VehicleShape.twoWheeler;
    if (_threeWheelerMakes.contains(make)) return VehicleShape.threeWheeler;
    if (_sixWheelerMakes.contains(make)) return VehicleShape.sixWheeler;
    return VehicleShape.fourWheeler;
  }
}

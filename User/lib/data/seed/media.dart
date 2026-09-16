import '../models/enums.dart';

/// Bundled imagery.
///
/// Brand marks come from the Simple Icons set (CC0) and photography from
/// Unsplash, both pulled once and shipped with the app rather than fetched at
/// runtime — so cards render instantly, look identical on every device and
/// never show a broken image when the phone is offline.
///
/// Every file is named for what is actually in the frame, so a category can
/// never end up illustrated by something unrelated.
class Media {
  const Media._();

  static const String _brands = 'assets/brands';
  static const String _photos = 'assets/photos';

  /// Vector mark per brand id. Mercedes-Benz is a raster fallback.
  static const Map<String, String> brandLogo = {
    'maruti': '$_brands/maruti.svg',
    'hyundai': '$_brands/hyundai.svg',
    'tata': '$_brands/tata.svg',
    'mahindra': '$_brands/mahindra.svg',
    'honda': '$_brands/honda.svg',
    'toyota': '$_brands/toyota.svg',
    'kia': '$_brands/kia.svg',
    'mg': '$_brands/mg.svg',
    'vw': '$_brands/vw.svg',
    'skoda': '$_brands/skoda.svg',
    'renault': '$_brands/renault.svg',
    'nissan': '$_brands/nissan.svg',
    'ford': '$_brands/ford.svg',
    'jeep': '$_brands/jeep.svg',
    'bmw': '$_brands/bmw.svg',
    'mercedes': '$_brands/mercedes.png',
    'audi': '$_brands/audi.svg',
    'tesla': '$_brands/tesla.svg',
  };

  static String? logoFor(String brandId) => brandLogo[brandId];

  static bool isVector(String path) => path.endsWith('.svg');

  // --- workshop photography ------------------------------------------------

  /// Belts and pulleys, close up.
  static const String engine = '$_photos/engine.jpg';

  /// Technician with a laptop over an open engine bay.
  static const String diagnostics = '$_photos/diagnostics.jpg';

  /// Mechanic working under a raised bonnet.
  static const String workshop = '$_photos/workshop.jpg';

  /// Car in a bay with the bonnet open.
  static const String serviceBay = '$_photos/service-bay.jpg';

  /// Dim workshop with cars on lifts — the hero shot.
  static const String garage = '$_photos/garage.jpg';

  /// Shelves of shock absorbers and spares.
  static const String parts = '$_photos/parts.jpg';

  /// Technician holding tools.
  static const String tools = '$_photos/tools.jpg';

  /// Foam wash in progress.
  static const String wash = '$_photos/wash.jpg';

  /// Hands on the wheel, lit dashboard.
  static const String dashboard = '$_photos/dashboard.jpg';

  /// Tail lights on a wet city street.
  static const String road = '$_photos/road.jpg';

  /// Kept for callers that just want a generic hero.
  static const String heroGarage = garage;

  /// Category id -> hero photo used on category headers and detail pages.
  static const Map<String, String> categoryPhoto = {
    'periodic': engine,
    'ac': dashboard,
    'cleaning': wash,
    'denting': tools,
    'battery': diagnostics,
    'tyres': parts,
    'brakes': workshop,
    'suspension': parts,
    'electrical': diagnostics,
    'inspection': serviceBay,
  };

  static String photoForCategory(String id) => categoryPhoto[id] ?? garage;

  /// Inspection area -> the photo shown with a finding.
  static String photoForArea(String area) => switch (area.toLowerCase()) {
        'engine' => engine,
        'brakes' => workshop,
        'tyres' => parts,
        'battery' => diagnostics,
        'suspension' => parts,
        'ac' => dashboard,
        'electricals' => diagnostics,
        _ => serviceBay,
      };

  /// A car of roughly the right shape for the vehicle's body style.
  static String photoForBody(BodyType body) => switch (body) {
        BodyType.hatchback => '$_photos/hatchback.jpg',
        BodyType.sedan => '$_photos/sedan.jpg',
        BodyType.suv => '$_photos/suv.jpg',
        BodyType.muv => '$_photos/suv.jpg',
        BodyType.luxury => '$_photos/luxury.jpg',
        BodyType.ev => '$_photos/ev.jpg',
      };

  // --- car models ----------------------------------------------------------

  static const String _cars = 'assets/cars';

  /// Models with a photograph of their own in `assets/cars/`.
  ///
  /// The catalogue covers far more of the Indian market than we have licensed
  /// photography for, so this is the list of ids that actually have a file.
  /// Drop `<model id>.jpg` into assets/cars/, add the id here, and that model
  /// starts showing its own picture — no other code changes.
  static const Set<String> carsWithPhotos = {
    '3series', 'a4', 'alcazar', 'altroz', 'amaze', 'astor',
    'altok10', 'baleno', 'bolero', 'brezza', 'carens', 'cclass', 'celerio', 'city',
    'compass', 'creta', 'dzire', 'ecosport', 'elevate', 'ertiga', 'exter',
    'fortuner', 'fronx', 'gla', 'glanza', 'grandi10', 'grandvitara',
    'harrier', 'hector', 'hycross', 'hyryder', 'i20', 'innova', 'jazz',
    'kushaq', 'kwid', 'magnite', 'model3', 'nexon', 'nexonev', 'polo',
    'punch', 'q3', 'safari', 'scorpion', 'seltos', 'slavia', 'sonet',
    'swift', 'taigun', 'thar', 'tiago', 'triber', 'venue', 'verna',
    'virtus', 'wagonr', 'x1', 'xuv300', 'xuv700', 'zsev',
  };

  /// A photograph of that exact model where we have one, and a photograph of
  /// its body style where we do not — never a broken image or a grey box.
  static String carPhoto(String? modelId, {BodyType? body}) {
    if (modelId == null || modelId.isEmpty) {
      return photoForBody(body ?? BodyType.hatchback);
    }
    return carsWithPhotos.contains(modelId)
        ? '$_cars/$modelId.jpg'
        : photoForBody(body ?? BodyType.hatchback);
  }

  /// Offer banners, in rotation order.
  static const List<String> offerBanners = [wash, sedan, engine, road];

  static const String sedan = '$_photos/sedan.jpg';
}

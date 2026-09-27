import 'package:flutter/material.dart';

import '../models/entities.dart';
import '../models/enums.dart';

/// The service menu the app books against: the categories, packages, add-ons
/// and coupons on offer, and the brands and models a workshop in India sees.
///
/// This is the product catalogue, not a sample of anybody's data. Which
/// workshop is doing the work, and what they end up charging for it, comes
/// from that workshop over Supabase — see `Workshop` and `WorkshopCard`.
class Seed {
  const Seed._();

  // -------------------------------------------------------------------------
  // Brands & models
  // -------------------------------------------------------------------------

  /// Every marque a workshop in India actually sees. That includes the ones
  /// no longer sold here — a garage still services Chevrolets, Fiats and
  /// Ambassadors every week, so leaving them out would make the app unable
  /// to book half the cars that turn up.
  static const List<VehicleBrand> brands = [
    // --- mass market, currently selling --------------------------------
    VehicleBrand(id: 'maruti', name: 'Maruti Suzuki', logoUrl: '', popular: true, accent: 0xFF0F4C9B),
    VehicleBrand(id: 'hyundai', name: 'Hyundai', logoUrl: '', popular: true, accent: 0xFF00295B),
    VehicleBrand(id: 'tata', name: 'Tata', logoUrl: '', popular: true, accent: 0xFF1B3A93),
    VehicleBrand(id: 'mahindra', name: 'Mahindra', logoUrl: '', popular: true, accent: 0xFFB4121B),
    VehicleBrand(id: 'honda', name: 'Honda', logoUrl: '', popular: true, accent: 0xFFCC0000),
    VehicleBrand(id: 'toyota', name: 'Toyota', logoUrl: '', popular: true, accent: 0xFFD0021B),
    VehicleBrand(id: 'kia', name: 'Kia', logoUrl: '', popular: true, accent: 0xFF05141F),
    VehicleBrand(id: 'mg', name: 'MG', logoUrl: '', accent: 0xFF9A1B1B),
    VehicleBrand(id: 'vw', name: 'Volkswagen', logoUrl: '', accent: 0xFF0A2A5E),
    VehicleBrand(id: 'skoda', name: 'Skoda', logoUrl: '', accent: 0xFF0E5C39),
    VehicleBrand(id: 'renault', name: 'Renault', logoUrl: '', accent: 0xFFD4A017),
    VehicleBrand(id: 'nissan', name: 'Nissan', logoUrl: '', accent: 0xFF8C0A12),
    VehicleBrand(id: 'citroen', name: 'Citroen', logoUrl: '', accent: 0xFFB01C2E),
    VehicleBrand(id: 'jeep', name: 'Jeep', logoUrl: '', accent: 0xFF1F3F26),
    VehicleBrand(id: 'byd', name: 'BYD', logoUrl: '', accent: 0xFF0B3C7D),
    VehicleBrand(id: 'isuzu', name: 'Isuzu', logoUrl: '', accent: 0xFFD20A11),
    VehicleBrand(id: 'force', name: 'Force Motors', logoUrl: '', accent: 0xFF1F5FA9),

    // --- premium and luxury ---------------------------------------------
    VehicleBrand(id: 'bmw', name: 'BMW', logoUrl: '', accent: 0xFF0B5CA8),
    VehicleBrand(id: 'mercedes', name: 'Mercedes-Benz', logoUrl: '', accent: 0xFF262626),
    VehicleBrand(id: 'audi', name: 'Audi', logoUrl: '', accent: 0xFFBB0A1E),
    VehicleBrand(id: 'volvo', name: 'Volvo', logoUrl: '', accent: 0xFF003057),
    VehicleBrand(id: 'landrover', name: 'Land Rover', logoUrl: '', accent: 0xFF005A2B),
    VehicleBrand(id: 'jaguar', name: 'Jaguar', logoUrl: '', accent: 0xFF1B2A38),
    VehicleBrand(id: 'lexus', name: 'Lexus', logoUrl: '', accent: 0xFF1A1A1A),
    VehicleBrand(id: 'porsche', name: 'Porsche', logoUrl: '', accent: 0xFFB12B28),
    VehicleBrand(id: 'mini', name: 'MINI', logoUrl: '', accent: 0xFF1A1A1A),
    VehicleBrand(id: 'tesla', name: 'Tesla', logoUrl: '', accent: 0xFFB4121B),

    // --- no longer sold here, still on the road -------------------------
    VehicleBrand(id: 'chevrolet', name: 'Chevrolet', logoUrl: '', accent: 0xFFC9A227),
    VehicleBrand(id: 'ford', name: 'Ford', logoUrl: '', accent: 0xFF1B4C9C),
    VehicleBrand(id: 'fiat', name: 'Fiat', logoUrl: '', accent: 0xFF8C1A2B),
    VehicleBrand(id: 'datsun', name: 'Datsun', logoUrl: '', accent: 0xFF9B1B30),
    VehicleBrand(id: 'hindustan', name: 'Hindustan Motors', logoUrl: '', accent: 0xFF0E5C39),
    VehicleBrand(id: 'premier', name: 'Premier', logoUrl: '', accent: 0xFF3A4A5A),
    VehicleBrand(id: 'opel', name: 'Opel', logoUrl: '', accent: 0xFFB8A12B),
  ];

  /// Every model a workshop in India is likely to see, current and
  /// discontinued alike. A garage still services Ambassadors, Optras and
  /// Palios every week, so leaving them out would make the app unable to
  /// book half the cars that turn up at the gate.
  ///
  /// A model without a photograph of its own falls back to a picture of
  /// its body style - see [Media.carsWithPhotos].
  static const List<VehicleModel> models = [

    // Maruti Suzuki - Arena
    VehicleModel(id: 'altok10', brandId: 'maruti', name: 'Alto K10', body: BodyType.hatchback, variants: ['STD', 'LXi', 'VXi', 'VXi+']),
    VehicleModel(id: 'alto800', brandId: 'maruti', name: 'Alto 800', body: BodyType.hatchback, variants: ['STD', 'LXi', 'VXi']),
    VehicleModel(id: 'spresso', brandId: 'maruti', name: 'S-Presso', body: BodyType.hatchback, variants: ['LXi', 'VXi', 'ZXi', 'ZXi+']),
    VehicleModel(id: 'wagonr', brandId: 'maruti', name: 'WagonR', body: BodyType.hatchback, variants: ['LXi', 'VXi', 'ZXi']),
    VehicleModel(id: 'celerio', brandId: 'maruti', name: 'Celerio', body: BodyType.hatchback, variants: ['LXi', 'VXi', 'ZXi']),
    VehicleModel(id: 'swift', brandId: 'maruti', name: 'Swift', body: BodyType.hatchback, variants: ['LXi', 'VXi', 'ZXi', 'ZXi+']),
    VehicleModel(id: 'dzire', brandId: 'maruti', name: 'Dzire', body: BodyType.sedan, variants: ['LXi', 'VXi', 'ZXi', 'ZXi+']),
    VehicleModel(id: 'brezza', brandId: 'maruti', name: 'Brezza', body: BodyType.suv, variants: ['LXi', 'VXi', 'ZXi', 'ZXi+']),
    VehicleModel(id: 'ertiga', brandId: 'maruti', name: 'Ertiga', body: BodyType.muv, variants: ['LXi', 'VXi', 'ZXi']),
    VehicleModel(id: 'eeco', brandId: 'maruti', name: 'Eeco', body: BodyType.muv, variants: ['5 Seater', '7 Seater', 'Tour']),

    // Maruti Suzuki - Nexa
    VehicleModel(id: 'baleno', brandId: 'maruti', name: 'Baleno', body: BodyType.hatchback, variants: ['Sigma', 'Delta', 'Zeta', 'Alpha']),
    VehicleModel(id: 'ignis', brandId: 'maruti', name: 'Ignis', body: BodyType.hatchback, variants: ['Sigma', 'Delta', 'Zeta', 'Alpha']),
    VehicleModel(id: 'fronx', brandId: 'maruti', name: 'Fronx', body: BodyType.suv, variants: ['Sigma', 'Delta', 'Zeta', 'Alpha']),
    VehicleModel(id: 'ciaz', brandId: 'maruti', name: 'Ciaz', body: BodyType.sedan, variants: ['Sigma', 'Delta', 'Zeta', 'Alpha']),
    VehicleModel(id: 'grandvitara', brandId: 'maruti', name: 'Grand Vitara', body: BodyType.suv, variants: ['Sigma', 'Delta', 'Zeta', 'Alpha']),
    VehicleModel(id: 'xl6', brandId: 'maruti', name: 'XL6', body: BodyType.muv, variants: ['Zeta', 'Alpha', 'Alpha+']),
    VehicleModel(id: 'jimny', brandId: 'maruti', name: 'Jimny', body: BodyType.suv, variants: ['Zeta', 'Alpha']),
    VehicleModel(id: 'invicto', brandId: 'maruti', name: 'Invicto', body: BodyType.muv, variants: ['Zeta+', 'Alpha+']),
    VehicleModel(id: 'scross', brandId: 'maruti', name: 'S-Cross', body: BodyType.suv, variants: ['Sigma', 'Delta', 'Zeta', 'Alpha']),

    // Maruti Suzuki - older models still on the road
    VehicleModel(id: 'maruti800', brandId: 'maruti', name: '800', body: BodyType.hatchback, variants: ['STD', 'AC', 'Old']),
    VehicleModel(id: 'omni', brandId: 'maruti', name: 'Omni', body: BodyType.muv, variants: ['STD', 'E', 'Cargo']),
    VehicleModel(id: 'gypsy', brandId: 'maruti', name: 'Gypsy', body: BodyType.suv, variants: ['King', 'MG410']),
    VehicleModel(id: 'zen', brandId: 'maruti', name: 'Zen', body: BodyType.hatchback, variants: ['LX', 'VX', 'Classic']),
    VehicleModel(id: 'zenestilo', brandId: 'maruti', name: 'Zen Estilo', body: BodyType.hatchback, variants: ['LX', 'VXi']),
    VehicleModel(id: 'esteem', brandId: 'maruti', name: 'Esteem', body: BodyType.sedan, variants: ['LX', 'VX', 'AX']),
    VehicleModel(id: 'altoold', brandId: 'maruti', name: 'Alto', body: BodyType.hatchback, variants: ['STD', 'LX', 'LXi']),
    VehicleModel(id: 'ritz', brandId: 'maruti', name: 'Ritz', body: BodyType.hatchback, variants: ['LXi', 'VXi', 'ZXi']),
    VehicleModel(id: 'astar', brandId: 'maruti', name: 'A-Star', body: BodyType.hatchback, variants: ['LXi', 'VXi', 'ZXi']),
    VehicleModel(id: 'sx4', brandId: 'maruti', name: 'SX4', body: BodyType.sedan, variants: ['VXi', 'ZXi']),
    VehicleModel(id: 'versa', brandId: 'maruti', name: 'Versa', body: BodyType.muv, variants: ['DX', 'DX2']),
    VehicleModel(id: 'kizashi', brandId: 'maruti', name: 'Kizashi', body: BodyType.sedan, variants: ['MT', 'AT']),
    VehicleModel(id: 'balenosedan', brandId: 'maruti', name: 'Baleno (Sedan)', body: BodyType.sedan, variants: ['LXi', 'VXi']),

    // Hyundai
    VehicleModel(id: 'santro', brandId: 'hyundai', name: 'Santro', body: BodyType.hatchback, variants: ['Era', 'Magna', 'Sportz', 'Asta']),
    VehicleModel(id: 'grandi10', brandId: 'hyundai', name: 'Grand i10 Nios', body: BodyType.hatchback, variants: ['Era', 'Magna', 'Sportz', 'Asta']),
    VehicleModel(id: 'i20', brandId: 'hyundai', name: 'i20', body: BodyType.hatchback, variants: ['Era', 'Magna', 'Sportz', 'Asta']),
    VehicleModel(id: 'aura', brandId: 'hyundai', name: 'Aura', body: BodyType.sedan, variants: ['E', 'S', 'SX', 'SX(O)']),
    VehicleModel(id: 'verna', brandId: 'hyundai', name: 'Verna', body: BodyType.sedan, variants: ['E', 'S', 'SX', 'SX(O)']),
    VehicleModel(id: 'exter', brandId: 'hyundai', name: 'Exter', body: BodyType.suv, variants: ['EX', 'S', 'SX']),
    VehicleModel(id: 'venue', brandId: 'hyundai', name: 'Venue', body: BodyType.suv, variants: ['E', 'S', 'SX', 'SX(O)']),
    VehicleModel(id: 'creta', brandId: 'hyundai', name: 'Creta', body: BodyType.suv, variants: ['E', 'EX', 'S', 'SX', 'SX(O)']),
    VehicleModel(id: 'cretaev', brandId: 'hyundai', name: 'Creta Electric', body: BodyType.ev, variants: ['Executive', 'Smart', 'Premium']),
    VehicleModel(id: 'alcazar', brandId: 'hyundai', name: 'Alcazar', body: BodyType.muv, variants: ['Prestige', 'Platinum', 'Signature']),
    VehicleModel(id: 'tucson', brandId: 'hyundai', name: 'Tucson', body: BodyType.suv, variants: ['Platinum', 'Signature']),
    VehicleModel(id: 'ioniq5', brandId: 'hyundai', name: 'Ioniq 5', body: BodyType.ev, variants: ['Standard', 'Long Range']),
    VehicleModel(id: 'konaev', brandId: 'hyundai', name: 'Kona Electric', body: BodyType.ev, variants: ['Premium', 'Premium DT']),

    // Hyundai - older models still on the road
    VehicleModel(id: 'santroxing', brandId: 'hyundai', name: 'Santro Xing', body: BodyType.hatchback, variants: ['XK', 'XL', 'XO']),
    VehicleModel(id: 'i10', brandId: 'hyundai', name: 'i10', body: BodyType.hatchback, variants: ['Era', 'Magna', 'Sportz', 'Asta']),
    VehicleModel(id: 'eon', brandId: 'hyundai', name: 'Eon', body: BodyType.hatchback, variants: ['D-Lite', 'Era', 'Magna', 'Sportz']),
    VehicleModel(id: 'getz', brandId: 'hyundai', name: 'Getz', body: BodyType.hatchback, variants: ['GLE', 'GLS', 'GVS']),
    VehicleModel(id: 'xcent', brandId: 'hyundai', name: 'Xcent', body: BodyType.sedan, variants: ['Base', 'S', 'SX']),
    VehicleModel(id: 'accent', brandId: 'hyundai', name: 'Accent', body: BodyType.sedan, variants: ['GLE', 'GLS', 'Viva']),
    VehicleModel(id: 'elantra', brandId: 'hyundai', name: 'Elantra', body: BodyType.sedan, variants: ['S', 'SX', 'SX(O)']),
    VehicleModel(id: 'sonata', brandId: 'hyundai', name: 'Sonata', body: BodyType.sedan, variants: ['Embera', 'Transform']),
    VehicleModel(id: 'santafe', brandId: 'hyundai', name: 'Santa Fe', body: BodyType.suv, variants: ['2WD', '4WD']),

    // Tata
    VehicleModel(id: 'tiago', brandId: 'tata', name: 'Tiago', body: BodyType.hatchback, variants: ['XE', 'XM', 'XT', 'XZ+']),
    VehicleModel(id: 'tiagoev', brandId: 'tata', name: 'Tiago EV', body: BodyType.ev, variants: ['XE', 'XT', 'XZ+']),
    VehicleModel(id: 'altroz', brandId: 'tata', name: 'Altroz', body: BodyType.hatchback, variants: ['Smart', 'Pure', 'Creative', 'Accomplished']),
    VehicleModel(id: 'tigor', brandId: 'tata', name: 'Tigor', body: BodyType.sedan, variants: ['XE', 'XM', 'XZ', 'XZ+']),
    VehicleModel(id: 'tigorev', brandId: 'tata', name: 'Tigor EV', body: BodyType.ev, variants: ['XE', 'XM', 'XZ+']),
    VehicleModel(id: 'punch', brandId: 'tata', name: 'Punch', body: BodyType.suv, variants: ['Pure', 'Adventure', 'Accomplished']),
    VehicleModel(id: 'punchev', brandId: 'tata', name: 'Punch EV', body: BodyType.ev, variants: ['Smart', 'Adventure', 'Empowered']),
    VehicleModel(id: 'nexon', brandId: 'tata', name: 'Nexon', body: BodyType.suv, variants: ['Smart', 'Pure', 'Creative', 'Fearless']),
    VehicleModel(id: 'nexonev', brandId: 'tata', name: 'Nexon EV', body: BodyType.ev, variants: ['Creative', 'Fearless', 'Empowered']),
    VehicleModel(id: 'curvv', brandId: 'tata', name: 'Curvv', body: BodyType.suv, variants: ['Smart', 'Pure', 'Creative', 'Accomplished']),
    VehicleModel(id: 'curvvev', brandId: 'tata', name: 'Curvv EV', body: BodyType.ev, variants: ['Creative', 'Accomplished', 'Empowered']),
    VehicleModel(id: 'harrier', brandId: 'tata', name: 'Harrier', body: BodyType.suv, variants: ['Smart', 'Pure', 'Adventure', 'Fearless']),
    VehicleModel(id: 'harrierev', brandId: 'tata', name: 'Harrier EV', body: BodyType.ev, variants: ['Adventure', 'Empowered']),
    VehicleModel(id: 'safari', brandId: 'tata', name: 'Safari', body: BodyType.suv, variants: ['Smart', 'Pure', 'Adventure', 'Accomplished']),

    // Tata - older models still on the road
    VehicleModel(id: 'indica', brandId: 'tata', name: 'Indica', body: BodyType.hatchback, variants: ['V2', 'eV2', 'DLS']),
    VehicleModel(id: 'vista', brandId: 'tata', name: 'Indica Vista', body: BodyType.hatchback, variants: ['Aura', 'Aqua', 'Terra']),
    VehicleModel(id: 'indigo', brandId: 'tata', name: 'Indigo', body: BodyType.sedan, variants: ['LS', 'LX', 'GLS']),
    VehicleModel(id: 'indigocs', brandId: 'tata', name: 'Indigo eCS', body: BodyType.sedan, variants: ['LS', 'LX', 'VX']),
    VehicleModel(id: 'manza', brandId: 'tata', name: 'Manza', body: BodyType.sedan, variants: ['Aqua', 'Aura', 'Elan']),
    VehicleModel(id: 'zest', brandId: 'tata', name: 'Zest', body: BodyType.sedan, variants: ['XE', 'XM', 'XT']),
    VehicleModel(id: 'bolt', brandId: 'tata', name: 'Bolt', body: BodyType.hatchback, variants: ['XE', 'XM', 'XT']),
    VehicleModel(id: 'nano', brandId: 'tata', name: 'Nano', body: BodyType.hatchback, variants: ['STD', 'CX', 'LX', 'GenX']),
    VehicleModel(id: 'sumo', brandId: 'tata', name: 'Sumo', body: BodyType.muv, variants: ['CX', 'EX', 'Victa']),
    VehicleModel(id: 'sumogold', brandId: 'tata', name: 'Sumo Gold', body: BodyType.muv, variants: ['CX', 'EX', 'GX']),
    VehicleModel(id: 'safaristorme', brandId: 'tata', name: 'Safari Storme', body: BodyType.suv, variants: ['EX', 'VX', 'Varicor']),
    VehicleModel(id: 'hexa', brandId: 'tata', name: 'Hexa', body: BodyType.muv, variants: ['XE', 'XM', 'XT']),
    VehicleModel(id: 'aria', brandId: 'tata', name: 'Aria', body: BodyType.muv, variants: ['Pure', 'Pleasure', 'Prestige']),
    VehicleModel(id: 'venture', brandId: 'tata', name: 'Venture', body: BodyType.muv, variants: ['CX', 'EX', 'GX']),

    // Mahindra
    VehicleModel(id: 'xuv300', brandId: 'mahindra', name: 'XUV 3XO', body: BodyType.suv, variants: ['MX1', 'MX2', 'MX3', 'AX7']),
    VehicleModel(id: 'xuv400', brandId: 'mahindra', name: 'XUV400 EV', body: BodyType.ev, variants: ['EC Pro', 'EL Pro']),
    VehicleModel(id: 'bolero', brandId: 'mahindra', name: 'Bolero', body: BodyType.suv, variants: ['B4', 'B6', 'B6(O)']),
    VehicleModel(id: 'boleroneo', brandId: 'mahindra', name: 'Bolero Neo', body: BodyType.suv, variants: ['N4', 'N8', 'N10']),
    VehicleModel(id: 'thar', brandId: 'mahindra', name: 'Thar', body: BodyType.suv, variants: ['AX(O)', 'LX']),
    VehicleModel(id: 'tharroxx', brandId: 'mahindra', name: 'Thar Roxx', body: BodyType.suv, variants: ['MX1', 'MX3', 'AX5L', 'AX7L']),
    VehicleModel(id: 'scorpion', brandId: 'mahindra', name: 'Scorpio-N', body: BodyType.suv, variants: ['Z2', 'Z4', 'Z6', 'Z8L']),
    VehicleModel(id: 'scorpioclassic', brandId: 'mahindra', name: 'Scorpio Classic', body: BodyType.suv, variants: ['S', 'S11']),
    VehicleModel(id: 'xuv700', brandId: 'mahindra', name: 'XUV700', body: BodyType.suv, variants: ['MX', 'AX3', 'AX5', 'AX7']),
    VehicleModel(id: 'marazzo', brandId: 'mahindra', name: 'Marazzo', body: BodyType.muv, variants: ['M2', 'M4+', 'M6+']),
    VehicleModel(id: 'be6', brandId: 'mahindra', name: 'BE 6', body: BodyType.ev, variants: ['Pack One', 'Pack Two', 'Pack Three']),
    VehicleModel(id: 'xev9e', brandId: 'mahindra', name: 'XEV 9e', body: BodyType.ev, variants: ['Pack One', 'Pack Two', 'Pack Three']),

    // Mahindra - older models still on the road
    VehicleModel(id: 'scorpio', brandId: 'mahindra', name: 'Scorpio', body: BodyType.suv, variants: ['S2', 'S4', 'S10']),
    VehicleModel(id: 'xuv500', brandId: 'mahindra', name: 'XUV500', body: BodyType.suv, variants: ['W4', 'W6', 'W8', 'W11']),
    VehicleModel(id: 'xylo', brandId: 'mahindra', name: 'Xylo', body: BodyType.muv, variants: ['D2', 'E4', 'H4', 'H9']),
    VehicleModel(id: 'quanto', brandId: 'mahindra', name: 'Quanto', body: BodyType.suv, variants: ['C2', 'C4', 'C8']),
    VehicleModel(id: 'tuv300', brandId: 'mahindra', name: 'TUV300', body: BodyType.suv, variants: ['T4', 'T6', 'T8']),
    VehicleModel(id: 'nuvosport', brandId: 'mahindra', name: 'NuvoSport', body: BodyType.suv, variants: ['N4', 'N6', 'N8']),
    VehicleModel(id: 'kuv100', brandId: 'mahindra', name: 'KUV100 NXT', body: BodyType.suv, variants: ['K2', 'K4', 'K6', 'K8']),
    VehicleModel(id: 'verito', brandId: 'mahindra', name: 'Verito', body: BodyType.sedan, variants: ['D2', 'D4', 'D6']),
    VehicleModel(id: 'veritovibe', brandId: 'mahindra', name: 'Verito Vibe', body: BodyType.hatchback, variants: ['D2', 'D4', 'D6']),
    VehicleModel(id: 'logan', brandId: 'mahindra', name: 'Logan', body: BodyType.sedan, variants: ['GL', 'GLX']),
    VehicleModel(id: 'alturas', brandId: 'mahindra', name: 'Alturas G4', body: BodyType.suv, variants: ['2WD', '4WD']),
    VehicleModel(id: 'e2o', brandId: 'mahindra', name: 'e2o Plus', body: BodyType.ev, variants: ['P4', 'P6', 'P8']),

    // Honda
    VehicleModel(id: 'amaze', brandId: 'honda', name: 'Amaze', body: BodyType.sedan, variants: ['E', 'S', 'VX', 'ZX']),
    VehicleModel(id: 'city', brandId: 'honda', name: 'City', body: BodyType.sedan, variants: ['SV', 'V', 'VX', 'ZX']),
    VehicleModel(id: 'elevate', brandId: 'honda', name: 'Elevate', body: BodyType.suv, variants: ['S', 'V', 'VX', 'ZX']),

    // Honda - older models still on the road
    VehicleModel(id: 'jazz', brandId: 'honda', name: 'Jazz', body: BodyType.hatchback, variants: ['V', 'VX', 'ZX']),
    VehicleModel(id: 'brio', brandId: 'honda', name: 'Brio', body: BodyType.hatchback, variants: ['E', 'S', 'VX']),
    VehicleModel(id: 'wrv', brandId: 'honda', name: 'WR-V', body: BodyType.suv, variants: ['S', 'VX']),
    VehicleModel(id: 'brv', brandId: 'honda', name: 'BR-V', body: BodyType.muv, variants: ['S', 'V', 'VX']),
    VehicleModel(id: 'mobilio', brandId: 'honda', name: 'Mobilio', body: BodyType.muv, variants: ['E', 'S', 'V', 'RS']),
    VehicleModel(id: 'civic', brandId: 'honda', name: 'Civic', body: BodyType.sedan, variants: ['V', 'VX', 'ZX']),
    VehicleModel(id: 'accord', brandId: 'honda', name: 'Accord', body: BodyType.luxury, variants: ['VTi-L', 'Hybrid']),
    VehicleModel(id: 'crv', brandId: 'honda', name: 'CR-V', body: BodyType.suv, variants: ['2WD', '4WD']),

    // Toyota
    VehicleModel(id: 'glanza', brandId: 'toyota', name: 'Glanza', body: BodyType.hatchback, variants: ['E', 'S', 'G', 'V']),
    VehicleModel(id: 'taisor', brandId: 'toyota', name: 'Urban Cruiser Taisor', body: BodyType.suv, variants: ['E', 'S', 'G', 'V']),
    VehicleModel(id: 'hyryder', brandId: 'toyota', name: 'Urban Cruiser Hyryder', body: BodyType.suv, variants: ['E', 'S', 'G', 'V']),
    VehicleModel(id: 'rumion', brandId: 'toyota', name: 'Rumion', body: BodyType.muv, variants: ['S', 'G', 'V']),
    VehicleModel(id: 'innova', brandId: 'toyota', name: 'Innova Crysta', body: BodyType.muv, variants: ['G', 'GX', 'VX', 'ZX']),
    VehicleModel(id: 'hycross', brandId: 'toyota', name: 'Innova Hycross', body: BodyType.muv, variants: ['G', 'GX', 'VX', 'ZX']),
    VehicleModel(id: 'fortuner', brandId: 'toyota', name: 'Fortuner', body: BodyType.suv, variants: ['4x2', '4x4', 'Legender']),
    VehicleModel(id: 'camry', brandId: 'toyota', name: 'Camry', body: BodyType.luxury, variants: ['Hybrid']),
    VehicleModel(id: 'vellfire', brandId: 'toyota', name: 'Vellfire', body: BodyType.luxury, variants: ['Executive Lounge']),
    VehicleModel(id: 'landcruiser', brandId: 'toyota', name: 'Land Cruiser', body: BodyType.suv, variants: ['LC300', 'LC250']),

    // Toyota - older models still on the road
    VehicleModel(id: 'qualis', brandId: 'toyota', name: 'Qualis', body: BodyType.muv, variants: ['FS', 'GS', 'GST']),
    VehicleModel(id: 'etios', brandId: 'toyota', name: 'Etios', body: BodyType.sedan, variants: ['J', 'G', 'V', 'VX']),
    VehicleModel(id: 'etiosliva', brandId: 'toyota', name: 'Etios Liva', body: BodyType.hatchback, variants: ['J', 'G', 'V', 'VX']),
    VehicleModel(id: 'corolla', brandId: 'toyota', name: 'Corolla', body: BodyType.sedan, variants: ['H1', 'H2', 'H3']),
    VehicleModel(id: 'corollaaltis', brandId: 'toyota', name: 'Corolla Altis', body: BodyType.sedan, variants: ['J', 'G', 'GL', 'VL']),
    VehicleModel(id: 'yaris', brandId: 'toyota', name: 'Yaris', body: BodyType.sedan, variants: ['J', 'G', 'V', 'VX']),
    VehicleModel(id: 'urbancruiser', brandId: 'toyota', name: 'Urban Cruiser', body: BodyType.suv, variants: ['Mid', 'High', 'Premium']),

    // Kia
    VehicleModel(id: 'sonet', brandId: 'kia', name: 'Sonet', body: BodyType.suv, variants: ['HTE', 'HTK', 'HTX', 'GTX']),
    VehicleModel(id: 'syros', brandId: 'kia', name: 'Syros', body: BodyType.suv, variants: ['HTK', 'HTK+', 'HTX', 'HTX+']),
    VehicleModel(id: 'seltos', brandId: 'kia', name: 'Seltos', body: BodyType.suv, variants: ['HTE', 'HTK', 'HTX', 'GTX']),
    VehicleModel(id: 'carens', brandId: 'kia', name: 'Carens', body: BodyType.muv, variants: ['Premium', 'Prestige', 'Luxury']),
    VehicleModel(id: 'carnival', brandId: 'kia', name: 'Carnival', body: BodyType.muv, variants: ['Limousine', 'Premium']),
    VehicleModel(id: 'ev6', brandId: 'kia', name: 'EV6', body: BodyType.ev, variants: ['GT Line', 'GT Line AWD']),
    VehicleModel(id: 'ev9', brandId: 'kia', name: 'EV9', body: BodyType.ev, variants: ['GT Line AWD']),

    // MG
    VehicleModel(id: 'comet', brandId: 'mg', name: 'Comet EV', body: BodyType.ev, variants: ['Pace', 'Play', 'Plush']),
    VehicleModel(id: 'astor', brandId: 'mg', name: 'Astor', body: BodyType.suv, variants: ['Style', 'Super', 'Smart', 'Sharp']),
    VehicleModel(id: 'windsor', brandId: 'mg', name: 'Windsor EV', body: BodyType.ev, variants: ['Excite', 'Exclusive', 'Essence']),
    VehicleModel(id: 'zsev', brandId: 'mg', name: 'ZS EV', body: BodyType.ev, variants: ['Excite', 'Exclusive']),
    VehicleModel(id: 'hector', brandId: 'mg', name: 'Hector', body: BodyType.suv, variants: ['Style', 'Smart', 'Sharp', 'Savvy']),
    VehicleModel(id: 'hectorplus', brandId: 'mg', name: 'Hector Plus', body: BodyType.muv, variants: ['Style', 'Smart', 'Sharp']),
    VehicleModel(id: 'gloster', brandId: 'mg', name: 'Gloster', body: BodyType.suv, variants: ['Super', 'Smart', 'Sharp', 'Savvy']),

    // Volkswagen
    VehicleModel(id: 'virtus', brandId: 'vw', name: 'Virtus', body: BodyType.sedan, variants: ['Comfortline', 'Highline', 'Topline', 'GT']),
    VehicleModel(id: 'taigun', brandId: 'vw', name: 'Taigun', body: BodyType.suv, variants: ['Comfortline', 'Highline', 'Topline', 'GT']),
    VehicleModel(id: 'tiguan', brandId: 'vw', name: 'Tiguan', body: BodyType.suv, variants: ['Elegance', 'R-Line']),

    // Volkswagen - older models still on the road
    VehicleModel(id: 'polo', brandId: 'vw', name: 'Polo', body: BodyType.hatchback, variants: ['Trendline', 'Comfortline', 'Highline', 'GT']),
    VehicleModel(id: 'vento', brandId: 'vw', name: 'Vento', body: BodyType.sedan, variants: ['Trendline', 'Comfortline', 'Highline']),
    VehicleModel(id: 'ameo', brandId: 'vw', name: 'Ameo', body: BodyType.sedan, variants: ['Trendline', 'Comfortline', 'Highline']),
    VehicleModel(id: 'jetta', brandId: 'vw', name: 'Jetta', body: BodyType.sedan, variants: ['Trendline', 'Comfortline', 'Highline']),
    VehicleModel(id: 'passat', brandId: 'vw', name: 'Passat', body: BodyType.luxury, variants: ['Comfortline', 'Highline']),

    // Skoda
    VehicleModel(id: 'kylaq', brandId: 'skoda', name: 'Kylaq', body: BodyType.suv, variants: ['Classic', 'Signature', 'Prestige']),
    VehicleModel(id: 'slavia', brandId: 'skoda', name: 'Slavia', body: BodyType.sedan, variants: ['Active', 'Ambition', 'Style']),
    VehicleModel(id: 'kushaq', brandId: 'skoda', name: 'Kushaq', body: BodyType.suv, variants: ['Active', 'Ambition', 'Style', 'Monte Carlo']),
    VehicleModel(id: 'kodiaq', brandId: 'skoda', name: 'Kodiaq', body: BodyType.suv, variants: ['Style', 'L&K', 'Sportline']),
    VehicleModel(id: 'superb', brandId: 'skoda', name: 'Superb', body: BodyType.luxury, variants: ['Sportline', 'L&K']),

    // Skoda - older models still on the road
    VehicleModel(id: 'rapid', brandId: 'skoda', name: 'Rapid', body: BodyType.sedan, variants: ['Rider', 'Ambition', 'Style', 'Monte Carlo']),
    VehicleModel(id: 'octavia', brandId: 'skoda', name: 'Octavia', body: BodyType.sedan, variants: ['Ambition', 'Style', 'L&K', 'vRS']),
    VehicleModel(id: 'fabia', brandId: 'skoda', name: 'Fabia', body: BodyType.hatchback, variants: ['Classic', 'Ambiente', 'Elegance']),
    VehicleModel(id: 'laura', brandId: 'skoda', name: 'Laura', body: BodyType.sedan, variants: ['Ambiente', 'Elegance', 'L&K']),
    VehicleModel(id: 'yeti', brandId: 'skoda', name: 'Yeti', body: BodyType.suv, variants: ['Ambition', 'Elegance']),

    // Renault
    VehicleModel(id: 'kwid', brandId: 'renault', name: 'Kwid', body: BodyType.hatchback, variants: ['RXE', 'RXL', 'RXT', 'Climber']),
    VehicleModel(id: 'triber', brandId: 'renault', name: 'Triber', body: BodyType.muv, variants: ['RXE', 'RXL', 'RXT', 'RXZ']),
    VehicleModel(id: 'kiger', brandId: 'renault', name: 'Kiger', body: BodyType.suv, variants: ['RXE', 'RXL', 'RXT', 'RXZ']),

    // Renault - older models still on the road
    VehicleModel(id: 'duster', brandId: 'renault', name: 'Duster', body: BodyType.suv, variants: ['RXE', 'RXL', 'RXS', 'RXZ']),
    VehicleModel(id: 'captur', brandId: 'renault', name: 'Captur', body: BodyType.suv, variants: ['RXE', 'RXL', 'RXT', 'Platine']),
    VehicleModel(id: 'lodgy', brandId: 'renault', name: 'Lodgy', body: BodyType.muv, variants: ['RXE', 'RXL', 'RXZ', 'Stepway']),
    VehicleModel(id: 'scala', brandId: 'renault', name: 'Scala', body: BodyType.sedan, variants: ['RXE', 'RXL', 'RXZ']),
    VehicleModel(id: 'pulse', brandId: 'renault', name: 'Pulse', body: BodyType.hatchback, variants: ['RXE', 'RXL', 'RXZ']),
    VehicleModel(id: 'fluence', brandId: 'renault', name: 'Fluence', body: BodyType.sedan, variants: ['E2', 'E4']),
    VehicleModel(id: 'koleos', brandId: 'renault', name: 'Koleos', body: BodyType.suv, variants: ['2WD', '4WD']),

    // Nissan
    VehicleModel(id: 'magnite', brandId: 'nissan', name: 'Magnite', body: BodyType.suv, variants: ['XE', 'XL', 'XV', 'XV Premium']),

    // Nissan - older models still on the road
    VehicleModel(id: 'micra', brandId: 'nissan', name: 'Micra', body: BodyType.hatchback, variants: ['XE', 'XL', 'XV']),
    VehicleModel(id: 'sunny', brandId: 'nissan', name: 'Sunny', body: BodyType.sedan, variants: ['XE', 'XL', 'XV']),
    VehicleModel(id: 'terrano', brandId: 'nissan', name: 'Terrano', body: BodyType.suv, variants: ['XE', 'XL', 'XV']),
    VehicleModel(id: 'kicks', brandId: 'nissan', name: 'Kicks', body: BodyType.suv, variants: ['XL', 'XV', 'XV Premium']),
    VehicleModel(id: 'evalia', brandId: 'nissan', name: 'Evalia', body: BodyType.muv, variants: ['XE', 'XL', 'XV']),
    VehicleModel(id: 'xtrail', brandId: 'nissan', name: 'X-Trail', body: BodyType.suv, variants: ['SL', 'SLX']),

    // Citroen
    VehicleModel(id: 'c3', brandId: 'citroen', name: 'C3', body: BodyType.hatchback, variants: ['Live', 'Feel', 'Shine']),
    VehicleModel(id: 'ec3', brandId: 'citroen', name: 'eC3', body: BodyType.ev, variants: ['Live', 'Feel', 'Shine']),
    VehicleModel(id: 'c3aircross', brandId: 'citroen', name: 'C3 Aircross', body: BodyType.suv, variants: ['You', 'Plus', 'Max']),
    VehicleModel(id: 'basalt', brandId: 'citroen', name: 'Basalt', body: BodyType.suv, variants: ['You', 'Plus', 'Max']),
    VehicleModel(id: 'c5aircross', brandId: 'citroen', name: 'C5 Aircross', body: BodyType.suv, variants: ['Feel', 'Shine']),

    // Jeep
    VehicleModel(id: 'compass', brandId: 'jeep', name: 'Compass', body: BodyType.suv, variants: ['Sport', 'Longitude', 'Limited', 'Trailhawk']),
    VehicleModel(id: 'meridian', brandId: 'jeep', name: 'Meridian', body: BodyType.suv, variants: ['Longitude', 'Limited', 'Overland']),
    VehicleModel(id: 'wrangler', brandId: 'jeep', name: 'Wrangler', body: BodyType.suv, variants: ['Unlimited', 'Rubicon']),
    VehicleModel(id: 'grandcherokee', brandId: 'jeep', name: 'Grand Cherokee', body: BodyType.suv, variants: ['Limited', 'Summit']),

    // BYD, Isuzu, Force
    VehicleModel(id: 'atto3', brandId: 'byd', name: 'Atto 3', body: BodyType.ev, variants: ['Dynamic', 'Premium', 'Superior']),
    VehicleModel(id: 'seal', brandId: 'byd', name: 'Seal', body: BodyType.ev, variants: ['Dynamic', 'Premium', 'Performance']),
    VehicleModel(id: 'emax7', brandId: 'byd', name: 'eMAX 7', body: BodyType.ev, variants: ['Premium', 'Superior']),
    VehicleModel(id: 'dmax', brandId: 'isuzu', name: 'D-Max V-Cross', body: BodyType.suv, variants: ['High', 'Z Prestige']),
    VehicleModel(id: 'mux', brandId: 'isuzu', name: 'MU-X', body: BodyType.suv, variants: ['4x2', '4x4']),
    VehicleModel(id: 'gurkha', brandId: 'force', name: 'Gurkha', body: BodyType.suv, variants: ['3-Door', '5-Door']),
    VehicleModel(id: 'traveller', brandId: 'force', name: 'Traveller', body: BodyType.muv, variants: ['3350', '3700', 'Monobus']),

    // BMW
    VehicleModel(id: '2series', brandId: 'bmw', name: '2 Series Gran Coupe', body: BodyType.sedan, variants: ['Sport', 'M Sport']),
    VehicleModel(id: '3series', brandId: 'bmw', name: '3 Series', body: BodyType.sedan, variants: ['Sport', 'Luxury Line', 'M Sport']),
    VehicleModel(id: '5series', brandId: 'bmw', name: '5 Series', body: BodyType.luxury, variants: ['Luxury Line', 'M Sport']),
    VehicleModel(id: '7series', brandId: 'bmw', name: '7 Series', body: BodyType.luxury, variants: ['Pure Excellence', 'M Sport']),
    VehicleModel(id: 'x1', brandId: 'bmw', name: 'X1', body: BodyType.suv, variants: ['xLine', 'M Sport']),
    VehicleModel(id: 'x3', brandId: 'bmw', name: 'X3', body: BodyType.suv, variants: ['xLine', 'M Sport']),
    VehicleModel(id: 'x5', brandId: 'bmw', name: 'X5', body: BodyType.suv, variants: ['xLine', 'M Sport']),
    VehicleModel(id: 'x7', brandId: 'bmw', name: 'X7', body: BodyType.suv, variants: ['Pure Excellence', 'M Sport']),
    VehicleModel(id: 'ix1', brandId: 'bmw', name: 'iX1', body: BodyType.ev, variants: ['xLine', 'M Sport']),
    VehicleModel(id: 'i4', brandId: 'bmw', name: 'i4', body: BodyType.ev, variants: ['eDrive40', 'M50']),

    // Mercedes-Benz
    VehicleModel(id: 'aclass', brandId: 'mercedes', name: 'A-Class Limousine', body: BodyType.sedan, variants: ['A200', 'A200d']),
    VehicleModel(id: 'cclass', brandId: 'mercedes', name: 'C-Class', body: BodyType.luxury, variants: ['C200', 'C220d', 'C300']),
    VehicleModel(id: 'eclass', brandId: 'mercedes', name: 'E-Class', body: BodyType.luxury, variants: ['E200', 'E220d', 'E350d']),
    VehicleModel(id: 'sclass', brandId: 'mercedes', name: 'S-Class', body: BodyType.luxury, variants: ['S350d', 'S450', 'Maybach']),
    VehicleModel(id: 'gla', brandId: 'mercedes', name: 'GLA', body: BodyType.suv, variants: ['GLA200', 'GLA220d']),
    VehicleModel(id: 'glc', brandId: 'mercedes', name: 'GLC', body: BodyType.suv, variants: ['GLC300', 'GLC220d']),
    VehicleModel(id: 'gle', brandId: 'mercedes', name: 'GLE', body: BodyType.suv, variants: ['GLE300d', 'GLE450']),
    VehicleModel(id: 'gls', brandId: 'mercedes', name: 'GLS', body: BodyType.suv, variants: ['GLS400d', 'GLS450', 'Maybach']),
    VehicleModel(id: 'eqs', brandId: 'mercedes', name: 'EQS', body: BodyType.ev, variants: ['580 4MATIC', 'Maybach']),

    // Audi
    VehicleModel(id: 'a4', brandId: 'audi', name: 'A4', body: BodyType.sedan, variants: ['Premium', 'Premium Plus', 'Technology']),
    VehicleModel(id: 'a6', brandId: 'audi', name: 'A6', body: BodyType.luxury, variants: ['Premium Plus', 'Technology']),
    VehicleModel(id: 'a8', brandId: 'audi', name: 'A8 L', body: BodyType.luxury, variants: ['Celebration', 'Technology']),
    VehicleModel(id: 'q3', brandId: 'audi', name: 'Q3', body: BodyType.suv, variants: ['Premium Plus', 'Technology', 'Sportback']),
    VehicleModel(id: 'q5', brandId: 'audi', name: 'Q5', body: BodyType.suv, variants: ['Premium Plus', 'Technology']),
    VehicleModel(id: 'q7', brandId: 'audi', name: 'Q7', body: BodyType.suv, variants: ['Premium Plus', 'Technology']),
    VehicleModel(id: 'q8', brandId: 'audi', name: 'Q8', body: BodyType.suv, variants: ['Celebration', 'Technology']),
    VehicleModel(id: 'etrongt', brandId: 'audi', name: 'e-tron GT', body: BodyType.ev, variants: ['quattro', 'RS']),

    // Volvo, Land Rover, Jaguar, Lexus, Porsche, MINI, Tesla
    VehicleModel(id: 'xc40', brandId: 'volvo', name: 'XC40', body: BodyType.suv, variants: ['Ultimate', 'Recharge']),
    VehicleModel(id: 'xc60', brandId: 'volvo', name: 'XC60', body: BodyType.suv, variants: ['Ultimate B5']),
    VehicleModel(id: 'xc90', brandId: 'volvo', name: 'XC90', body: BodyType.suv, variants: ['Ultimate B6']),
    VehicleModel(id: 's60', brandId: 'volvo', name: 'S60', body: BodyType.sedan, variants: ['Ultimate B4']),
    VehicleModel(id: 'c40', brandId: 'volvo', name: 'C40 Recharge', body: BodyType.ev, variants: ['Ultimate']),
    VehicleModel(id: 'defender', brandId: 'landrover', name: 'Defender', body: BodyType.suv, variants: ['90', '110', '130']),
    VehicleModel(id: 'discovery', brandId: 'landrover', name: 'Discovery', body: BodyType.suv, variants: ['S', 'SE', 'HSE']),
    VehicleModel(id: 'discoverysport', brandId: 'landrover', name: 'Discovery Sport', body: BodyType.suv, variants: ['S', 'SE', 'Dynamic SE']),
    VehicleModel(id: 'rrevoque', brandId: 'landrover', name: 'Range Rover Evoque', body: BodyType.suv, variants: ['S', 'SE', 'Dynamic SE']),
    VehicleModel(id: 'rrvelar', brandId: 'landrover', name: 'Range Rover Velar', body: BodyType.suv, variants: ['S', 'Dynamic SE']),
    VehicleModel(id: 'rrsport', brandId: 'landrover', name: 'Range Rover Sport', body: BodyType.luxury, variants: ['SE', 'Dynamic SE', 'Autobiography']),
    VehicleModel(id: 'rangerover', brandId: 'landrover', name: 'Range Rover', body: BodyType.luxury, variants: ['SE', 'HSE', 'Autobiography']),
    VehicleModel(id: 'jaguarxe', brandId: 'jaguar', name: 'XE', body: BodyType.sedan, variants: ['Pure', 'Prestige', 'Portfolio']),
    VehicleModel(id: 'jaguarxf', brandId: 'jaguar', name: 'XF', body: BodyType.luxury, variants: ['Prestige', 'Portfolio', 'R-Dynamic']),
    VehicleModel(id: 'fpace', brandId: 'jaguar', name: 'F-Pace', body: BodyType.suv, variants: ['Prestige', 'Portfolio', 'R-Dynamic']),
    VehicleModel(id: 'lexuses', brandId: 'lexus', name: 'ES', body: BodyType.luxury, variants: ['300h Exquisite', '300h Luxury']),
    VehicleModel(id: 'lexusnx', brandId: 'lexus', name: 'NX', body: BodyType.suv, variants: ['350h Exquisite', '350h Luxury']),
    VehicleModel(id: 'lexusrx', brandId: 'lexus', name: 'RX', body: BodyType.suv, variants: ['350h Luxury', '500h F-Sport']),
    VehicleModel(id: 'lexuslm', brandId: 'lexus', name: 'LM', body: BodyType.luxury, variants: ['350h VIP']),
    VehicleModel(id: 'macan', brandId: 'porsche', name: 'Macan', body: BodyType.suv, variants: ['Base', 'S', 'GTS']),
    VehicleModel(id: 'cayenne', brandId: 'porsche', name: 'Cayenne', body: BodyType.suv, variants: ['Base', 'S', 'Coupe']),
    VehicleModel(id: 'taycan', brandId: 'porsche', name: 'Taycan', body: BodyType.ev, variants: ['Base', '4S', 'Turbo']),
    VehicleModel(id: 'panamera', brandId: 'porsche', name: 'Panamera', body: BodyType.luxury, variants: ['Base', '4', 'Turbo']),
    VehicleModel(id: 'minicooper', brandId: 'mini', name: 'Cooper', body: BodyType.hatchback, variants: ['Cooper S', 'JCW']),
    VehicleModel(id: 'minicountryman', brandId: 'mini', name: 'Countryman', body: BodyType.suv, variants: ['Cooper S', 'JCW']),
    VehicleModel(id: 'model3', brandId: 'tesla', name: 'Model 3', body: BodyType.ev, variants: ['RWD', 'Long Range', 'Performance']),
    VehicleModel(id: 'modely', brandId: 'tesla', name: 'Model Y', body: BodyType.ev, variants: ['RWD', 'Long Range', 'Performance']),

    // Chevrolet - no longer sold here, still on the road
    VehicleModel(id: 'spark', brandId: 'chevrolet', name: 'Spark', body: BodyType.hatchback, variants: ['PS', 'LS', 'LT']),
    VehicleModel(id: 'beat', brandId: 'chevrolet', name: 'Beat', body: BodyType.hatchback, variants: ['PS', 'LS', 'LT']),
    VehicleModel(id: 'sail', brandId: 'chevrolet', name: 'Sail', body: BodyType.sedan, variants: ['Base', 'LS', 'LT']),
    VehicleModel(id: 'sailuva', brandId: 'chevrolet', name: 'Sail U-VA', body: BodyType.hatchback, variants: ['Base', 'LS', 'LT']),
    VehicleModel(id: 'aveo', brandId: 'chevrolet', name: 'Aveo', body: BodyType.sedan, variants: ['LS', 'LT']),
    VehicleModel(id: 'aveouva', brandId: 'chevrolet', name: 'Aveo U-VA', body: BodyType.hatchback, variants: ['LS', 'LT']),
    VehicleModel(id: 'optra', brandId: 'chevrolet', name: 'Optra', body: BodyType.sedan, variants: ['LS', 'LT', 'Magnum', 'SRV']),
    VehicleModel(id: 'cruze', brandId: 'chevrolet', name: 'Cruze', body: BodyType.sedan, variants: ['LS', 'LT', 'LTZ']),
    VehicleModel(id: 'tavera', brandId: 'chevrolet', name: 'Tavera', body: BodyType.muv, variants: ['B1', 'B2', 'Neo']),
    VehicleModel(id: 'enjoy', brandId: 'chevrolet', name: 'Enjoy', body: BodyType.muv, variants: ['Base', 'LS', 'LT', 'LTZ']),
    VehicleModel(id: 'captiva', brandId: 'chevrolet', name: 'Captiva', body: BodyType.suv, variants: ['LT', 'LTZ']),
    VehicleModel(id: 'trailblazer', brandId: 'chevrolet', name: 'Trailblazer', body: BodyType.suv, variants: ['LTZ']),

    // Ford - no longer sold here, still on the road
    VehicleModel(id: 'figo', brandId: 'ford', name: 'Figo', body: BodyType.hatchback, variants: ['Ambiente', 'Trend', 'Titanium']),
    VehicleModel(id: 'freestyle', brandId: 'ford', name: 'Freestyle', body: BodyType.hatchback, variants: ['Ambiente', 'Trend', 'Titanium']),
    VehicleModel(id: 'aspire', brandId: 'ford', name: 'Aspire', body: BodyType.sedan, variants: ['Ambiente', 'Trend', 'Titanium']),
    VehicleModel(id: 'fiesta', brandId: 'ford', name: 'Fiesta', body: BodyType.sedan, variants: ['Ambiente', 'Trend', 'Titanium']),
    VehicleModel(id: 'ikon', brandId: 'ford', name: 'Ikon', body: BodyType.sedan, variants: ['Flair', 'Josh', 'NXT']),
    VehicleModel(id: 'fusion', brandId: 'ford', name: 'Fusion', body: BodyType.hatchback, variants: ['Base', 'Plus']),
    VehicleModel(id: 'ecosport', brandId: 'ford', name: 'EcoSport', body: BodyType.suv, variants: ['Ambiente', 'Trend', 'Titanium', 'S']),
    VehicleModel(id: 'endeavour', brandId: 'ford', name: 'Endeavour', body: BodyType.suv, variants: ['Trend', 'Titanium', 'Titanium+']),
    VehicleModel(id: 'mustang', brandId: 'ford', name: 'Mustang', body: BodyType.luxury, variants: ['GT Fastback']),

    // Fiat, Datsun, Opel and the classics
    VehicleModel(id: 'punto', brandId: 'fiat', name: 'Punto', body: BodyType.hatchback, variants: ['Active', 'Dynamic', 'Emotion', 'Abarth']),
    VehicleModel(id: 'linea', brandId: 'fiat', name: 'Linea', body: BodyType.sedan, variants: ['Active', 'Dynamic', 'Emotion']),
    VehicleModel(id: 'palio', brandId: 'fiat', name: 'Palio', body: BodyType.hatchback, variants: ['EL', 'ELX', 'Stile']),
    VehicleModel(id: 'unofiat', brandId: 'fiat', name: 'Uno', body: BodyType.hatchback, variants: ['Base', 'Diesel']),
    VehicleModel(id: 'siena', brandId: 'fiat', name: 'Siena', body: BodyType.sedan, variants: ['EL', 'ELX']),
    VehicleModel(id: 'avventura', brandId: 'fiat', name: 'Avventura', body: BodyType.hatchback, variants: ['Active', 'Dynamic', 'Emotion']),
    VehicleModel(id: 'datsungo', brandId: 'datsun', name: 'GO', body: BodyType.hatchback, variants: ['D', 'A', 'T', 'T(O)']),
    VehicleModel(id: 'datsungoplus', brandId: 'datsun', name: 'GO+', body: BodyType.muv, variants: ['D', 'A', 'T', 'T(O)']),
    VehicleModel(id: 'redigo', brandId: 'datsun', name: 'redi-GO', body: BodyType.hatchback, variants: ['D', 'A', 'T', 'T(O)']),
    VehicleModel(id: 'corsa', brandId: 'opel', name: 'Corsa', body: BodyType.sedan, variants: ['Sail', 'Swing', 'Joy']),
    VehicleModel(id: 'astra', brandId: 'opel', name: 'Astra', body: BodyType.sedan, variants: ['Club', 'Elite']),
    VehicleModel(id: 'ambassador', brandId: 'hindustan', name: 'Ambassador', body: BodyType.sedan, variants: ['Mark IV', 'Nova', 'Classic', 'Grand']),
    VehicleModel(id: 'contessa', brandId: 'hindustan', name: 'Contessa', body: BodyType.sedan, variants: ['Classic', 'Diesel']),
    VehicleModel(id: 'padmini', brandId: 'premier', name: 'Padmini', body: BodyType.sedan, variants: ['Deluxe', 'S1']),
    VehicleModel(id: 'premierrio', brandId: 'premier', name: 'Rio', body: BodyType.suv, variants: ['LX', 'GLX']),
  ];

  // -------------------------------------------------------------------------
  // Service categories
  // -------------------------------------------------------------------------

  static const List<ServiceCategory> categories = [
    ServiceCategory(
      id: 'periodic',
      name: 'Periodic service',
      tagline: 'Scheduled maintenance packages',
      icon: Icons.build_circle_rounded,
      accent: 0xFFFF5F2E,
      featured: true,
    ),
    ServiceCategory(
      id: 'ac',
      name: 'AC service & repair',
      tagline: 'Cooling checks, gas top-up, repair',
      icon: Icons.ac_unit_rounded,
      accent: 0xFF2F8FED,
      featured: true,
    ),
    ServiceCategory(
      id: 'cleaning',
      name: 'Cleaning & detailing',
      tagline: 'Spa, polish, deep interior clean',
      icon: Icons.auto_awesome_rounded,
      accent: 0xFF11A37F,
      featured: true,
    ),
    ServiceCategory(
      id: 'denting',
      name: 'Denting & painting',
      tagline: 'Panel, bumper and full body',
      icon: Icons.format_paint_rounded,
      accent: 0xFF8B5CF6,
      featured: true,
    ),
    ServiceCategory(
      id: 'battery',
      name: 'Battery',
      tagline: 'Testing, jump start, replacement',
      icon: Icons.battery_charging_full_rounded,
      accent: 0xFFE0A200,
      featured: true,
    ),
    ServiceCategory(
      id: 'tyres',
      name: 'Tyres & wheels',
      tagline: 'Alignment, balancing, replacement',
      icon: Icons.tire_repair_rounded,
      accent: 0xFF475569,
      featured: true,
    ),
    ServiceCategory(
      id: 'brakes',
      name: 'Brakes',
      tagline: 'Pads, discs and brake fluid',
      icon: Icons.disc_full_rounded,
      accent: 0xFFE02A2A,
      featured: true,
    ),
    ServiceCategory(
      id: 'suspension',
      name: 'Suspension & steering',
      tagline: 'Shockers, bushes, steering feel',
      icon: Icons.compress_rounded,
      accent: 0xFF0EA5A5,
      featured: true,
    ),
    ServiceCategory(
      id: 'electrical',
      name: 'Electrical & lights',
      tagline: 'Wiring, lights, diagnostics',
      icon: Icons.electrical_services_rounded,
      accent: 0xFF6366F1,
    ),
    ServiceCategory(
      id: 'inspection',
      name: 'Car inspection',
      tagline: 'General, pre-purchase, trip check',
      icon: Icons.fact_check_rounded,
      accent: 0xFF0F766E,
    ),
  ];

  // -------------------------------------------------------------------------
  // Packages
  // -------------------------------------------------------------------------

  static const List<ServicePackage> packages = [
    // --- Periodic ---------------------------------------------------------
    ServicePackage(
      id: 'basic-service',
      categoryId: 'periodic',
      name: 'Basic service',
      subtitle: 'Every 5,000 km — the essentials',
      mrp: 2899,
      price: 2039,
      durationHours: 4,
      warrantyMonths: 1,
      recommendedEveryKm: 5000,
      rating: 4.6,
      reviewCount: 1204,
      groups: ['Scheduled packages', 'Value services'],
      tags: ['9 services', 'Same day'],
      description:
          'A quick health top-up between major services. We change the engine oil, '
          'top up every fluid and run a 24-point safety check so nothing sneaks up on you.',
      includes: [
        'Engine oil replacement (semi-synthetic)',
        'Oil filter replacement',
        'Air filter cleaning',
        'Coolant top-up',
        'Brake fluid top-up',
        'Wiper fluid top-up',
        'Battery water top-up',
        'Tyre pressure check',
        '24-point safety inspection',
      ],
      excludes: [
        'Spare parts beyond the listed consumables',
        'Any repair work found during inspection',
        'AC gas refill',
      ],
    ),
    ServicePackage(
      id: 'standard-service',
      categoryId: 'periodic',
      name: 'Standard service',
      subtitle: 'Every 10,000 km — most popular',
      mrp: 4299,
      price: 3032,
      durationHours: 6,
      warrantyMonths: 3,
      recommendedEveryKm: 10000,
      popular: true,
      rating: 4.8,
      reviewCount: 3871,
      groups: ['Scheduled packages'],
      tags: ['15 services', 'Free pickup', '3 month warranty'],
      description:
          'The service most cars need once a year. Fresh synthetic oil, all four filters, '
          'a brake and suspension check, plus an interior vacuum and exterior wash before delivery.',
      includes: [
        'Engine oil replacement (fully synthetic)',
        'Oil filter replacement',
        'Air filter replacement',
        'AC / cabin filter cleaning',
        'Fuel filter check',
        'Brake inspection — front and rear',
        'Suspension inspection',
        'Battery health test',
        'Coolant top-up',
        'Brake fluid top-up',
        'Steering fluid check',
        'Wiper blade check',
        'Tyre pressure and tread check',
        'Interior vacuum',
        'Exterior wash and dry',
      ],
      excludes: [
        'Additional spare parts',
        'Major mechanical repairs',
        'Pickup outside the 12 km service radius',
      ],
    ),
    ServicePackage(
      id: 'comprehensive-service',
      categoryId: 'periodic',
      name: 'Comprehensive service',
      subtitle: 'Every 20,000 km — everything covered',
      mrp: 7499,
      price: 5249,
      durationHours: 8,
      warrantyMonths: 6,
      recommendedEveryKm: 20000,
      rating: 4.9,
      reviewCount: 1663,
      groups: ['Scheduled packages'],
      tags: ['24 services', 'Free pickup', '6 month warranty'],
      description:
          'Our deepest scheduled package. Everything in Standard plus spark plugs, '
          'throttle body cleaning, injector cleaning, brake work and a full detailing pass.',
      includes: [
        'Everything in Standard service',
        'Spark plug replacement',
        'Fuel injector cleaning',
        'Throttle body cleaning',
        'Brake pad cleaning and greasing',
        'Brake drum servicing',
        'Wheel alignment',
        'Wheel balancing',
        'Coolant replacement',
        'AC vent disinfectant',
        'Rubbing compound polish',
        'Under-body inspection',
        'Engine bay dressing',
        'Road test by senior technician',
      ],
      excludes: [
        'Timing belt / chain replacement',
        'Clutch and gearbox work',
        'Body repair and paint',
      ],
    ),
    ServicePackage(
      id: 'express-oil',
      categoryId: 'periodic',
      name: 'Express oil change',
      subtitle: 'In and out in 90 minutes',
      mrp: 1899,
      price: 1329,
      durationHours: 1.5,
      warrantyMonths: 1,
      recommendedEveryKm: 5000,
      rating: 4.5,
      reviewCount: 742,
      groups: ['Value services', 'Under ₹1499'],
      tags: ['90 mins', 'Walk-in'],
      description:
          'Oil and filter only, done while you wait. Ideal if your last full service was recent.',
      includes: [
        'Engine oil replacement',
        'Oil filter replacement',
        'Fluid level top-up',
        'Tyre pressure check',
      ],
      excludes: ['Filters other than oil', 'Wash and cleaning'],
    ),
    ServicePackage(
      id: 'winter-check',
      categoryId: 'periodic',
      name: 'Seasonal readiness check',
      subtitle: 'Battery, coolant, wipers, lights',
      mrp: 999,
      price: 499,
      durationHours: 1,
      warrantyMonths: 0,
      rating: 4.4,
      reviewCount: 388,
      groups: ['Under ₹1499', 'Value services'],
      tags: ['20 checks', 'Under ₹499'],
      description:
          'A short, sharp check before a season change or a long drive.',
      includes: [
        'Battery load test',
        'Coolant strength test',
        'Wiper blade check',
        'All lights check',
        'Tyre tread and pressure',
        'Brake feel test',
      ],
      excludes: ['Any parts replaced', 'Repairs'],
    ),

    // --- AC ---------------------------------------------------------------
    ServicePackage(
      id: 'ac-inspection',
      categoryId: 'ac',
      name: 'AC inspection',
      subtitle: 'Find out why it is not cooling',
      mrp: 799,
      price: 399,
      durationHours: 1,
      warrantyMonths: 0,
      rating: 4.5,
      reviewCount: 512,
      groups: ['Diagnostics', 'Under ₹1499'],
      tags: ['Under ₹499', '45 mins'],
      description: 'A technician measures vent temperature, checks pressures and traces leaks.',
      includes: [
        'Vent temperature measurement',
        'Compressor operation check',
        'Gas pressure test',
        'Condenser and fan check',
        'Leak trace with UV dye',
        'Written findings in the app',
      ],
      excludes: ['Gas refill', 'Parts and repair'],
    ),
    ServicePackage(
      id: 'ac-gas-refill',
      categoryId: 'ac',
      name: 'AC gas refill',
      subtitle: 'Evacuate, vacuum and recharge',
      mrp: 2999,
      price: 2099,
      durationHours: 2.5,
      warrantyMonths: 3,
      popular: true,
      rating: 4.7,
      reviewCount: 1290,
      groups: ['AC repair'],
      tags: ['R134a / R1234yf', '3 month warranty'],
      description:
          'Old refrigerant recovered, system vacuum tested, then recharged to the '
          'manufacturer specified weight.',
      includes: [
        'Refrigerant recovery',
        'Vacuum leak test',
        'Gas refill to OEM weight',
        'Compressor oil top-up',
        'Condenser cleaning',
        'Cooling performance test',
      ],
      excludes: ['Compressor, condenser or coil replacement', 'Pipe repair'],
    ),
    ServicePackage(
      id: 'ac-full-service',
      categoryId: 'ac',
      name: 'Complete AC service',
      subtitle: 'Cooling coil out, everything cleaned',
      mrp: 5499,
      price: 3849,
      durationHours: 6,
      warrantyMonths: 6,
      rating: 4.8,
      reviewCount: 604,
      groups: ['AC repair'],
      tags: ['Dashboard removal', '6 month warranty'],
      description:
          'The full treatment when airflow is weak or there is a smell. Cooling coil is '
          'removed, chemically cleaned and refitted with a new filter.',
      includes: [
        'Cooling coil removal and chemical cleaning',
        'Blower motor cleaning',
        'Cabin filter replacement',
        'Condenser flush',
        'Gas refill',
        'Anti-bacterial treatment',
        'Dashboard refit and test',
      ],
      excludes: ['Compressor replacement', 'Evaporator replacement'],
    ),

    // --- Cleaning ---------------------------------------------------------
    ServicePackage(
      id: 'exterior-wash',
      categoryId: 'cleaning',
      name: 'Premium exterior wash',
      subtitle: 'Foam wash, dry, tyre dressing',
      mrp: 699,
      price: 349,
      durationHours: 1,
      warrantyMonths: 0,
      rating: 4.6,
      reviewCount: 2210,
      groups: ['Wash', 'Under ₹1499'],
      tags: ['Under ₹499', '60 mins'],
      description: 'pH-neutral snow foam, two-bucket wash and a microfibre dry.',
      includes: [
        'Snow foam pre-wash',
        'Two-bucket hand wash',
        'Wheel and arch cleaning',
        'Microfibre dry',
        'Tyre dressing',
        'Glass cleaning',
      ],
      excludes: ['Interior cleaning', 'Polishing'],
    ),
    ServicePackage(
      id: 'car-spa',
      categoryId: 'cleaning',
      name: 'Car spa — inside out',
      subtitle: 'Interior deep clean + exterior polish',
      mrp: 3499,
      price: 2099,
      durationHours: 4,
      warrantyMonths: 0,
      popular: true,
      rating: 4.9,
      reviewCount: 1875,
      groups: ['Detailing'],
      tags: ['Most booked', '4 hours'],
      description:
          'Interior shampoo, dashboard dressing and a machine polish that takes the '
          'swirls out of the paint.',
      includes: [
        'Interior vacuum, roof to boot',
        'Seat and carpet shampoo',
        'Dashboard and console dressing',
        'Leather conditioning where applicable',
        'Exterior foam wash',
        'Machine polish with rubbing compound',
        'Tyre and trim dressing',
        'Glass polish inside and out',
      ],
      excludes: ['Paint correction beyond one stage', 'Ceramic coating'],
    ),
    ServicePackage(
      id: 'ceramic-coating',
      categoryId: 'cleaning',
      name: '9H ceramic coating',
      subtitle: '3-year gloss and protection',
      mrp: 21999,
      price: 15399,
      durationHours: 48,
      warrantyMonths: 36,
      rating: 4.9,
      reviewCount: 214,
      groups: ['Detailing'],
      tags: ['2 days', '3 year warranty'],
      description:
          'Multi-stage paint correction followed by a 9H ceramic layer. Your car leaves '
          'glossier than it was new and stays easier to wash for years.',
      includes: [
        'Clay bar decontamination',
        'Two-stage paint correction',
        'Panel-wipe preparation',
        'Two coats of 9H ceramic',
        'Glass and wheel coating',
        'Infrared curing',
        'Aftercare kit',
      ],
      excludes: ['Dent and scratch repair', 'Paint work'],
    ),
    ServicePackage(
      id: 'interior-detail',
      categoryId: 'cleaning',
      name: 'Interior deep clean',
      subtitle: 'Shampoo, steam and sanitise',
      mrp: 2499,
      price: 1499,
      durationHours: 3,
      warrantyMonths: 0,
      rating: 4.7,
      reviewCount: 932,
      groups: ['Detailing'],
      tags: ['Steam clean'],
      description: 'For cars that carry kids, pets or long road trips.',
      includes: [
        'Full vacuum including boot',
        'Fabric seat shampoo',
        'Carpet and mat shampoo',
        'Steam sanitisation',
        'AC vent disinfectant',
        'Odour neutraliser',
      ],
      excludes: ['Exterior wash', 'Roof lining repair'],
    ),

    // --- Denting & painting -----------------------------------------------
    ServicePackage(
      id: 'dent-removal',
      categoryId: 'denting',
      name: 'Paintless dent removal',
      subtitle: 'Per panel, no repaint needed',
      mrp: 1999,
      price: 1299,
      durationHours: 3,
      warrantyMonths: 3,
      rating: 4.6,
      reviewCount: 431,
      groups: ['Denting'],
      tags: ['Per panel'],
      description:
          'Shallow dents pushed out from behind the panel so the factory paint stays intact.',
      includes: [
        'Panel assessment',
        'Paintless dent removal',
        'Panel polish',
        'Photo before and after',
      ],
      excludes: ['Dents with cracked paint', 'Creased or stretched metal'],
    ),
    ServicePackage(
      id: 'bumper-paint',
      categoryId: 'denting',
      name: 'Bumper repair & paint',
      subtitle: 'Front or rear, colour matched',
      mrp: 4999,
      price: 3499,
      durationHours: 24,
      warrantyMonths: 12,
      popular: true,
      rating: 4.8,
      reviewCount: 688,
      groups: ['Painting'],
      tags: ['1 day', '1 year warranty'],
      description:
          'Scuffs and cracks repaired, primed and sprayed in a dust-free booth with '
          'computerised colour matching.',
      includes: [
        'Bumper removal and repair',
        'Crack welding where needed',
        'Primer and sanding',
        'Computerised colour match',
        'Booth paint and bake',
        'Clear coat and polish',
        'Refit and alignment',
      ],
      excludes: ['Bumper replacement', 'Sensor or camera recalibration'],
    ),
    ServicePackage(
      id: 'panel-paint',
      categoryId: 'denting',
      name: 'Panel painting',
      subtitle: 'Per door, fender or bonnet',
      mrp: 5999,
      price: 4199,
      durationHours: 24,
      warrantyMonths: 12,
      rating: 4.7,
      reviewCount: 372,
      groups: ['Painting'],
      tags: ['Per panel', '1 year warranty'],
      description: 'Full panel respray with blending into adjacent panels.',
      includes: [
        'Dent pulling and filling',
        'Sanding and primer',
        'Colour match and spray',
        'Blending into adjacent panels',
        'Clear coat and buff',
      ],
      excludes: ['Panel replacement', 'Structural repair'],
    ),
    ServicePackage(
      id: 'full-body-paint',
      categoryId: 'denting',
      name: 'Full body paint',
      subtitle: 'Complete respray, booth finish',
      mrp: 54999,
      price: 38499,
      durationHours: 120,
      warrantyMonths: 24,
      rating: 4.8,
      reviewCount: 96,
      groups: ['Painting'],
      tags: ['5 days', '2 year warranty'],
      description: 'Every panel stripped, prepped and sprayed. Includes door shuts and jambs.',
      includes: [
        'Full strip and mask',
        'Dent and rust repair',
        'Primer across all panels',
        'Two-coat base and clear',
        'Door jambs and shuts',
        'Cut and polish',
        'Reassembly',
      ],
      excludes: ['Panel replacement', 'Interior trim repair'],
    ),

    // --- Battery -----------------------------------------------------------
    ServicePackage(
      id: 'battery-check',
      categoryId: 'battery',
      name: 'Battery health check',
      subtitle: 'Load test and charging system',
      mrp: 499,
      price: 199,
      durationHours: 0.5,
      warrantyMonths: 0,
      rating: 4.5,
      reviewCount: 611,
      groups: ['Diagnostics', 'Under ₹1499'],
      tags: ['Under ₹499', '30 mins'],
      description: 'Cranking amps, voltage drop and alternator output measured and logged.',
      includes: [
        'Battery load test',
        'Voltage and CCA report',
        'Alternator output test',
        'Terminal cleaning',
      ],
      excludes: ['Battery replacement', 'Wiring repair'],
    ),
    ServicePackage(
      id: 'battery-replace',
      categoryId: 'battery',
      name: 'Battery replacement',
      subtitle: 'Fitted at home or at the garage',
      mrp: 6499,
      price: 4899,
      durationHours: 1,
      warrantyMonths: 36,
      popular: true,
      rating: 4.8,
      reviewCount: 1422,
      groups: ['Replacement'],
      tags: ['Doorstep', '3 year warranty'],
      description:
          'Genuine Exide / Amaron battery supplied and fitted, old battery taken away.',
      includes: [
        'New battery matched to your car',
        'Fitment and terminal protection',
        'Old battery buy-back',
        'Charging system test',
        'Warranty registration',
      ],
      excludes: ['Alternator repair', 'Wiring harness work'],
    ),
    ServicePackage(
      id: 'jump-start',
      categoryId: 'battery',
      name: 'Jump start at your location',
      subtitle: 'Technician reaches you',
      mrp: 799,
      price: 599,
      durationHours: 0.5,
      warrantyMonths: 0,
      rating: 4.7,
      reviewCount: 508,
      groups: ['Roadside'],
      tags: ['On-site', '30 min ETA'],
      description: 'A technician reaches you with a booster pack and gets you moving.',
      includes: [
        'On-site jump start',
        'Battery quick test',
        'Advice on next steps',
      ],
      excludes: ['Battery replacement', 'Towing'],
    ),

    // --- Tyres -------------------------------------------------------------
    ServicePackage(
      id: 'wheel-alignment',
      categoryId: 'tyres',
      name: 'Wheel alignment',
      subtitle: '3D camera alignment, all four wheels',
      mrp: 1099,
      price: 699,
      durationHours: 1,
      warrantyMonths: 1,
      rating: 4.6,
      reviewCount: 1654,
      groups: ['Alignment', 'Under ₹1499'],
      tags: ['3D machine', '60 mins'],
      description:
          'Camber, caster and toe set back to factory spec on a 3D alignment rig, with '
          'a printed before/after report.',
      includes: [
        'Four-wheel 3D alignment',
        'Camber, caster, toe correction',
        'Steering angle reset',
        'Before and after report',
      ],
      excludes: ['Suspension part replacement', 'Balancing'],
    ),
    ServicePackage(
      id: 'wheel-balancing',
      categoryId: 'tyres',
      name: 'Wheel balancing',
      subtitle: 'Removes vibration at speed',
      mrp: 799,
      price: 499,
      durationHours: 1,
      warrantyMonths: 1,
      rating: 4.5,
      reviewCount: 1102,
      groups: ['Alignment', 'Under ₹1499'],
      tags: ['Under ₹499', '4 wheels'],
      description: 'Each wheel spun and weighted so the steering stops shaking above 80 km/h.',
      includes: [
        'Four-wheel dynamic balancing',
        'Weight fitment',
        'Valve check',
        'Pressure set to spec',
      ],
      excludes: ['Alignment', 'Tyre replacement'],
    ),
    ServicePackage(
      id: 'tyre-rotation',
      categoryId: 'tyres',
      name: 'Tyre rotation',
      subtitle: 'Even out wear across four tyres',
      mrp: 599,
      price: 349,
      durationHours: 0.75,
      warrantyMonths: 0,
      rating: 4.4,
      reviewCount: 487,
      groups: ['Alignment', 'Under ₹1499'],
      tags: ['Under ₹499'],
      description: 'Cross-pattern rotation with tread depth logged for each wheel.',
      includes: [
        'Cross rotation of four tyres',
        'Tread depth measurement',
        'Pressure correction',
        'Torque to spec',
      ],
      excludes: ['Balancing', 'Alignment'],
    ),
    ServicePackage(
      id: 'tyre-replace',
      categoryId: 'tyres',
      name: 'Tyre replacement',
      subtitle: 'Per tyre, fitted and balanced',
      mrp: 6999,
      price: 5249,
      durationHours: 1.5,
      warrantyMonths: 12,
      rating: 4.7,
      reviewCount: 693,
      groups: ['Replacement'],
      tags: ['MRF / Apollo / CEAT'],
      description: 'Choose your brand at the garage — fitment, balancing and disposal included.',
      includes: [
        'New tyre supply and fitment',
        'Dynamic balancing',
        'New valve',
        'Old tyre disposal',
        'Alignment check',
      ],
      excludes: ['Alloy wheel repair', 'TPMS sensor'],
    ),

    // --- Brakes ------------------------------------------------------------
    ServicePackage(
      id: 'brake-inspection',
      categoryId: 'brakes',
      name: 'Brake inspection',
      subtitle: 'Pad thickness, discs and fluid',
      mrp: 599,
      price: 249,
      durationHours: 0.75,
      warrantyMonths: 0,
      rating: 4.6,
      reviewCount: 744,
      groups: ['Brake maintenance', 'Under ₹1499'],
      tags: ['Under ₹499'],
      description: 'Wheels off, every pad and disc measured and photographed for you.',
      includes: [
        'All four wheels removed',
        'Pad thickness measured',
        'Disc run-out and wear check',
        'Caliper and hose inspection',
        'Brake fluid moisture test',
        'Photo report in the app',
      ],
      excludes: ['Parts', 'Labour for repairs'],
    ),
    ServicePackage(
      id: 'brake-pads-front',
      categoryId: 'brakes',
      name: 'Front brake pad replacement',
      subtitle: 'OE-grade pads, fitted and bedded',
      mrp: 3999,
      price: 2799,
      durationHours: 2,
      warrantyMonths: 12,
      popular: true,
      rating: 4.8,
      reviewCount: 1187,
      groups: ['Brake maintenance'],
      tags: ['1 year warranty'],
      description: 'New pads, cleaned carriers, greased slides and a proper bedding-in road test.',
      includes: [
        'Front brake pads (pair)',
        'Caliper clean and grease',
        'Disc surface clean',
        'Brake fluid top-up',
        'Bedding-in road test',
      ],
      excludes: ['Disc replacement', 'Caliper overhaul'],
    ),
    ServicePackage(
      id: 'brake-disc',
      categoryId: 'brakes',
      name: 'Brake disc replacement',
      subtitle: 'Per axle, pads recommended with it',
      mrp: 7499,
      price: 5624,
      durationHours: 3,
      warrantyMonths: 12,
      rating: 4.7,
      reviewCount: 322,
      groups: ['Brake maintenance'],
      tags: ['Per axle'],
      description: 'Warped or under-thickness discs replaced in pairs so braking stays even.',
      includes: [
        'Brake discs (pair)',
        'Hub face cleaning',
        'Pad compatibility check',
        'Torque to spec',
        'Road test',
      ],
      excludes: ['Brake pads', 'ABS sensor repair'],
    ),
    ServicePackage(
      id: 'brake-fluid',
      categoryId: 'brakes',
      name: 'Brake fluid replacement',
      subtitle: 'Full flush and bleed, DOT 4',
      mrp: 1799,
      price: 1259,
      durationHours: 1.5,
      warrantyMonths: 6,
      rating: 4.6,
      reviewCount: 498,
      groups: ['Brake maintenance', 'Under ₹1499'],
      tags: ['DOT 4'],
      description: 'Old fluid pushed out at all four corners so the pedal firms up again.',
      includes: [
        'DOT 4 fluid replacement',
        'Four-corner bleed',
        'Clutch line bleed where shared',
        'Moisture test after',
      ],
      excludes: ['Master cylinder repair', 'Line replacement'],
    ),

    // --- Suspension --------------------------------------------------------
    ServicePackage(
      id: 'suspension-inspection',
      categoryId: 'suspension',
      name: 'Suspension inspection',
      subtitle: 'Find the knock or the bounce',
      mrp: 699,
      price: 299,
      durationHours: 1,
      warrantyMonths: 0,
      rating: 4.5,
      reviewCount: 402,
      groups: ['Diagnostics', 'Under ₹1499'],
      tags: ['Under ₹499', 'On lift'],
      description: 'On a lift, every bush, link and shocker checked with the wheels loaded.',
      includes: [
        'Shock absorber leak check',
        'Bush and link play test',
        'Ball joint and tie rod check',
        'Spring and mount inspection',
        'Road test with technician',
      ],
      excludes: ['Parts', 'Repair labour'],
    ),
    ServicePackage(
      id: 'shock-absorber',
      categoryId: 'suspension',
      name: 'Shock absorber replacement',
      subtitle: 'Per pair, front or rear',
      mrp: 9999,
      price: 7499,
      durationHours: 4,
      warrantyMonths: 12,
      rating: 4.7,
      reviewCount: 268,
      groups: ['Repair'],
      tags: ['Per pair', '1 year warranty'],
      description: 'New shockers with fresh mounts and bump stops, then an alignment check.',
      includes: [
        'Shock absorbers (pair)',
        'Top mount and bump stop',
        'Spring transfer',
        'Torque under load',
        'Alignment check',
      ],
      excludes: ['Coil springs', 'Wheel alignment charges if needed'],
    ),
    ServicePackage(
      id: 'steering-service',
      categoryId: 'suspension',
      name: 'Steering system service',
      subtitle: 'Rack, pump and fluid',
      mrp: 2999,
      price: 2099,
      durationHours: 2.5,
      warrantyMonths: 6,
      rating: 4.6,
      reviewCount: 187,
      groups: ['Repair'],
      tags: ['Power steering'],
      description: 'Heavy or noisy steering diagnosed, fluid flushed and the rack inspected.',
      includes: [
        'Power steering fluid flush',
        'Rack boot inspection',
        'Pump pressure test',
        'Belt tension check',
        'Steering angle reset',
      ],
      excludes: ['Rack replacement', 'Pump replacement'],
    ),

    // --- Electrical --------------------------------------------------------
    ServicePackage(
      id: 'obd-scan',
      categoryId: 'electrical',
      name: 'Full OBD diagnostics',
      subtitle: 'Every module scanned and explained',
      mrp: 999,
      price: 499,
      durationHours: 1,
      warrantyMonths: 0,
      rating: 4.7,
      reviewCount: 873,
      groups: ['Diagnostics', 'Under ₹1499'],
      tags: ['Under ₹499', 'Live data'],
      description:
          'Engine, ABS, airbag, transmission and body modules scanned, with every fault '
          'code explained in plain language.',
      includes: [
        'All-module fault code scan',
        'Live sensor data review',
        'Freeze frame analysis',
        'Plain-language report',
        'Clear codes after repair',
      ],
      excludes: ['Repairs for the faults found', 'Module coding'],
    ),
    ServicePackage(
      id: 'headlight-restore',
      categoryId: 'electrical',
      name: 'Headlight restoration',
      subtitle: 'Clear up yellowed lenses',
      mrp: 1499,
      price: 899,
      durationHours: 1.5,
      warrantyMonths: 6,
      rating: 4.6,
      reviewCount: 356,
      groups: ['Lights', 'Under ₹1499'],
      tags: ['Pair'],
      description: 'Wet-sanded, polished and UV sealed — night visibility improves noticeably.',
      includes: [
        'Multi-stage wet sanding',
        'Machine polish',
        'UV protective sealant',
        'Beam alignment check',
      ],
      excludes: ['Headlight replacement', 'Bulb upgrade'],
    ),
    ServicePackage(
      id: 'wiring-repair',
      categoryId: 'electrical',
      name: 'Electrical fault repair',
      subtitle: 'Tracing shorts, drains and dead circuits',
      mrp: 2499,
      price: 1749,
      durationHours: 3,
      warrantyMonths: 6,
      rating: 4.5,
      reviewCount: 241,
      groups: ['Repair'],
      tags: ['Per fault'],
      description: 'Parasitic drains, dead windows and flickering lights traced to the wire.',
      includes: [
        'Circuit tracing',
        'Parasitic drain test',
        'Fuse and relay check',
        'Connector repair',
        'Harness taping',
      ],
      excludes: ['Replacement modules', 'Aftermarket accessory faults'],
    ),

    // --- Inspection --------------------------------------------------------
    ServicePackage(
      id: 'general-inspection',
      categoryId: 'inspection',
      name: '38-point general inspection',
      subtitle: 'Photo report delivered in the app',
      mrp: 999,
      price: 0,
      durationHours: 1,
      warrantyMonths: 0,
      rating: 4.9,
      reviewCount: 2954,
      groups: ['Inspection'],
      tags: ['Free with any service'],
      description:
          'Free with every service booking. 38 checkpoints, each photographed and graded '
          'green, amber or red so you can see exactly what we saw.',
      includes: [
        'Engine bay and fluids',
        'Brakes at all four corners',
        'Suspension and steering',
        'Tyres and alignment wear',
        'Battery and charging',
        'Lights and electricals',
        'AC performance',
        'Photo evidence for every finding',
      ],
      excludes: ['Repairs', 'Parts'],
    ),
    ServicePackage(
      id: 'prepurchase-inspection',
      categoryId: 'inspection',
      name: 'Pre-purchase inspection',
      subtitle: 'Before you buy a used car',
      mrp: 2999,
      price: 1999,
      durationHours: 2.5,
      warrantyMonths: 0,
      popular: true,
      rating: 4.9,
      reviewCount: 618,
      groups: ['Inspection'],
      tags: ['200+ checks', 'Same day report'],
      description:
          'We go to the car, put it on a lift where possible, check paint thickness on every '
          'panel and hand you a verdict before you pay for it.',
      includes: [
        'Paint thickness on every panel',
        'Accident and repair history read',
        'Engine compression and leak-down',
        'Chassis and under-body check',
        'Full OBD scan with module history',
        'Odometer tamper check',
        'Test drive assessment',
        'Written buy / do not buy verdict',
      ],
      excludes: ['RC and insurance verification', 'Negotiation on your behalf'],
    ),
    ServicePackage(
      id: 'trip-inspection',
      categoryId: 'inspection',
      name: 'Long trip readiness',
      subtitle: 'Before a highway run',
      mrp: 1299,
      price: 799,
      durationHours: 1.5,
      warrantyMonths: 0,
      rating: 4.7,
      reviewCount: 421,
      groups: ['Inspection', 'Under ₹1499'],
      tags: ['Highway ready'],
      description: 'The checks that matter at 100 km/h for six hours straight.',
      includes: [
        'Tyre condition including spare',
        'Brake pad life for the distance',
        'Coolant and oil condition',
        'Belt and hose check',
        'Battery and charging',
        'All lights and wipers',
        'Emergency kit check',
      ],
      excludes: ['Repairs', 'Parts'],
    ),
  ];

  // -------------------------------------------------------------------------
  // Add-ons
  // -------------------------------------------------------------------------

  static const List<AddOn> addOns = [
    AddOn(
      id: 'ao-interior',
      name: 'Interior vacuum & dressing',
      price: 399,
      mrp: 699,
      blurb: 'Seats, carpets and dashboard freshened up',
      icon: Icons.cleaning_services_rounded,
      durationMins: 45,
    ),
    AddOn(
      id: 'ao-ac-disinfect',
      name: 'AC disinfectant treatment',
      price: 449,
      mrp: 799,
      blurb: 'Kills the smell at the vents, not just over it',
      icon: Icons.sanitizer_rounded,
      durationMins: 30,
    ),
    AddOn(
      id: 'ao-alignment',
      name: 'Wheel alignment',
      price: 599,
      mrp: 1099,
      blurb: 'Add it to any service at a discount',
      icon: Icons.settings_input_component_rounded,
      durationMins: 60,
    ),
    AddOn(
      id: 'ao-engine-flush',
      name: 'Engine flush',
      price: 349,
      mrp: 599,
      blurb: 'Clears sludge before the fresh oil goes in',
      icon: Icons.water_drop_rounded,
      durationMins: 20,
    ),
    AddOn(
      id: 'ao-polish',
      name: 'Exterior polish',
      price: 899,
      mrp: 1499,
      blurb: 'One-stage machine polish for gloss',
      icon: Icons.auto_awesome_rounded,
      durationMins: 90,
    ),
    AddOn(
      id: 'ao-wiper',
      name: 'Wiper blade pair',
      price: 649,
      mrp: 999,
      blurb: 'Silicone blades, fitted',
      icon: Icons.water_rounded,
      durationMins: 10,
    ),
    AddOn(
      id: 'ao-teflon',
      name: 'Teflon coating',
      price: 2499,
      mrp: 3999,
      blurb: '6 months of water beading',
      icon: Icons.shield_rounded,
      durationMins: 120,
    ),
    AddOn(
      id: 'ao-pickup',
      name: 'Pickup & drop',
      price: 299,
      mrp: 499,
      blurb: 'We collect and return within 12 km',
      icon: Icons.local_shipping_rounded,
      durationMins: 0,
    ),
  ];

  static const int pickupFee = 299;

  // -------------------------------------------------------------------------
  // Coupons
  // -------------------------------------------------------------------------

  static List<Coupon> coupons() => [
        Coupon(
          code: 'FIRST500',
          title: '₹500 off your first service',
          blurb: 'Valid on orders above ₹2,000',
          isPercent: false,
          value: 500,
          minOrder: 2000,
          validTill: DateTime.now().add(const Duration(days: 45)),
          accent: 0xFFFF5F2E,
        ),
        Coupon(
          code: 'SAVE10',
          title: '10% off, up to ₹1,200',
          blurb: 'Any periodic service package',
          isPercent: true,
          value: 10,
          minOrder: 1500,
          maxDiscount: 1200,
          validTill: DateTime.now().add(const Duration(days: 20)),
          accent: 0xFF2F8FED,
        ),
        Coupon(
          code: 'SPA299',
          title: '₹299 off car spa',
          blurb: 'Detailing and cleaning services',
          isPercent: false,
          value: 299,
          minOrder: 1500,
          validTill: DateTime.now().add(const Duration(days: 12)),
          accent: 0xFF11A37F,
        ),
        Coupon(
          code: 'AC15',
          title: '15% off AC services',
          blurb: 'Beat the heat, up to ₹900 off',
          isPercent: true,
          value: 15,
          minOrder: 1999,
          maxDiscount: 900,
          validTill: DateTime.now().add(const Duration(days: 30)),
          accent: 0xFF8B5CF6,
        ),
      ];

  // -------------------------------------------------------------------------
  // Help content
  // -------------------------------------------------------------------------

  static const List<FaqItem> faqs = [
    FaqItem(
      'How does pickup and drop work?',
      'Pick a slot and an address when you book. A trained driver arrives within the '
          '30-minute window, sends you a photo of the car before driving off, and returns '
          'it after the service. Pickup is free on Standard and Comprehensive packages within 12 km.',
      'Booking',
    ),
    FaqItem(
      'Can I change or cancel my booking?',
      'Yes. Open the booking from My Bookings and use Reschedule or Cancel any time '
          'before the vehicle is received at the garage. There is no cancellation charge.',
      'Booking',
    ),
    FaqItem(
      'Will you start work without telling me the cost?',
      'Never. Anything beyond the package you booked is quoted as an estimate first. '
          'Work starts only on the items you approve in the app, and every approval is '
          'timestamped against your name.',
      'Estimates',
    ),
    FaqItem(
      'What if the garage finds something else mid-repair?',
      'They issue a revised estimate. You will see the previous total, the new total, '
          'the reason and exactly which items were added. The new items need your approval '
          'before anyone touches them.',
      'Estimates',
    ),
    FaqItem(
      'Are the spare parts genuine?',
      'We fit OEM or OES parts by default and tell you on the estimate when an aftermarket '
          'equivalent is being proposed, along with the price difference. Every part carries '
          'its stated warranty.',
      'Service',
    ),
    FaqItem(
      'What warranty do I get?',
      'Each package lists its own warranty — typically 1 month on basic, 3 months on '
          'standard, 6 months on comprehensive, and 1 year on most part replacements. '
          'Warranty terms appear on your invoice.',
      'Service',
    ),
    FaqItem(
      'How do I pay?',
      'UPI, credit or debit card, and net banking in the app, or cash and card at the '
          'garage. You pay only after the final invoice is generated, and every payment is '
          'attached to a specific invoice.',
      'Payments',
    ),
    FaqItem(
      'Where do I find my invoice later?',
      'Account → Service history, or open the booking itself. Invoices stay available '
          'for download and sharing permanently.',
      'Payments',
    ),
    FaqItem(
      'What does the digital inspection cover?',
      'Thirty-eight checkpoints across engine, brakes, suspension, tyres, battery, '
          'electricals and AC. Each is graded green, amber or red with a photo and a '
          'technician note.',
      'Service',
    ),
  ];

  static const List<String> chatTopics = [
    'Booking',
    'Pickup & drop',
    'Estimate',
    'Repair status',
    'Payment',
    'Something else',
  ];

  static const List<String> cancelReasons = [
    'Plan changed, I will rebook later',
    'Found a different time slot',
    'Vehicle is no longer available',
    'Price is higher than expected',
    'Booked by mistake',
    'Other',
  ];

  /// Slot times offered per day. Admin-controlled once Supabase is connected.
  static const List<String> slotTimes = [
    '09:00 AM',
    '10:00 AM',
    '11:00 AM',
    '12:00 PM',
    '02:00 PM',
    '03:00 PM',
    '04:00 PM',
    '05:00 PM',
  ];

  static const List<String> popularSearches = [
    'Car service',
    'AC gas refill',
    'Brake pads',
    'Wheel alignment',
    'Battery',
    'Car spa',
    'Dent removal',
    'Oil change',
  ];

  static ServicePackage? packageById(String id) {
    for (final p in packages) {
      if (p.id == id) return p;
    }
    return null;
  }

  static ServiceCategory? categoryById(String id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  static AddOn? addOnById(String id) {
    for (final a in addOns) {
      if (a.id == id) return a;
    }
    return null;
  }

  static List<ServicePackage> byCategory(String categoryId) =>
      packages.where((p) => p.categoryId == categoryId).toList();

  static List<VehicleModel> modelsOf(String brandId) =>
      models.where((m) => m.brandId == brandId).toList();

  static VehicleBrand? brandById(String id) {
    for (final b in brands) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// Finds the catalogue model behind a saved vehicle, so its real photo can
  /// be shown wherever the vehicle appears.
  static VehicleModel? modelByName(String brand, String model) {
    final b = brandByName(brand);
    for (final m in models) {
      if (m.name.toLowerCase() == model.toLowerCase() &&
          (b == null || m.brandId == b.id)) {
        return m;
      }
    }
    for (final m in models) {
      if (m.name.toLowerCase() == model.toLowerCase()) return m;
    }
    return null;
  }

  static VehicleBrand? brandByName(String name) {
    for (final b in brands) {
      if (b.name.toLowerCase() == name.toLowerCase()) return b;
    }
    return null;
  }
}

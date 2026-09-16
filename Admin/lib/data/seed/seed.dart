/// The fixed option lists the counter picks from, and the job card
/// numbering rule.
///
/// These are wording, not records: complaint and accessory checklists that
/// every workshop ticks the same way, and the default terms printed on a
/// bill. Everything that belongs to a particular workshop — its rate card,
/// its customers, its job cards — is created by that workshop.
class Seed {
  const Seed._();

  // --- picker presets ------------------------------------------------------

  /// The complaint checklist ticked at the counter, in the customer's words.
  static const List<String> voices = [
    'Full Body Check',
    'Oil Check and Change',
    'Mileage Check',
    'Brake Check',
    'Customization',
    'Balancing',
    'Wheel Alignment',
    'Accidental Repair',
    'General Repair',
    'Servicing',
    'AC Not Cooling',
    'Engine Noise',
    'Clutch Hard',
    'Steering Vibration',
    'Suspension Noise',
    'Battery Weak',
    'Overheating',
    'Pickup Low',
    'Water Wash',
    'Denting and Painting',
  ];

  /// What came in with the car, ticked so nothing goes missing.
  static const List<String> accessories = [
    'Stepney',
    'Jack',
    'Tool Kit',
    'Wheel Spanner',
    'Music System',
    'Speaker',
    'Floor Mat',
    'Seat Cover',
    'Mirror',
    'Wheel Cap',
    'Fire Extinguisher',
    'First Aid Kit',
    'Documents',
    'Fastag',
    'Perfume',
    'Mobile Charger',
  ];

  static const List<String> terms = [
    'Goods once sold will not be taken back.',
    'Warranty as per manufacturer policy only.',
    'Vehicle is parked at owner risk.',
    'Payment due on delivery.',
  ];

  /// `A0914-001` — a letter, the day stamp, then the running count.
  static String numberFor(DateTime day, int seq) {
    final mm = day.month.toString().padLeft(2, '0');
    final dd = day.day.toString().padLeft(2, '0');
    return 'A$mm$dd-${seq.toString().padLeft(3, '0')}';
  }
}

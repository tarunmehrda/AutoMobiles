import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

/// One person as the job card wants them: a name, a ten-digit mobile, and an
/// email if the phone happens to have one.
typedef ContactPick = ({String name, String phone, String email});

/// How the read went, so the counter is told the truth rather than shown an
/// empty list whatever the reason.
enum ContactsAccess {
  /// Contacts were read (possibly none exist).
  ok,

  /// No contact book here — web and desktop.
  unsupported,

  /// Refused this time; asking again is allowed.
  denied,

  /// Refused for good, or blocked by policy. Only Settings can undo it.
  blocked,

  /// The platform threw. Nothing to show, nothing to ask for.
  failed,
}

typedef ContactBook = ({ContactsAccess access, List<ContactPick> people});

/// The phone's own address book, read for the "Add from contacts" picker.
///
/// The permission is asked for here rather than assumed: the first-run screen
/// offers it, but a counter may have skipped that screen, said no, or been
/// handed a phone that was set up by someone else.
class DeviceContacts {
  const DeviceContacts._();

  /// The plugin ships Android, iOS and macOS only; everywhere else the method
  /// channel is simply missing.
  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  static const _empty = <ContactPick>[];

  static Future<ContactBook> read() async {
    if (!supported) {
      return (access: ContactsAccess.unsupported, people: _empty);
    }
    try {
      var status = await FlutterContacts.permissions.check(PermissionType.read);
      if (status != PermissionStatus.granted &&
          status != PermissionStatus.limited) {
        status = await FlutterContacts.permissions.request(PermissionType.read);
      }
      switch (status) {
        case PermissionStatus.granted:
        case PermissionStatus.limited:
          break;
        case PermissionStatus.permanentlyDenied:
        case PermissionStatus.restricted:
          return (access: ContactsAccess.blocked, people: _empty);
        case PermissionStatus.denied:
        case PermissionStatus.notDetermined:
          return (access: ContactsAccess.denied, people: _empty);
      }

      final raw = await FlutterContacts.getAll(
        properties: {ContactProperty.phone, ContactProperty.email},
      );
      return (access: ContactsAccess.ok, people: _tidy(raw));
    } on PlatformException {
      return (access: ContactsAccess.failed, people: _empty);
    } on MissingPluginException {
      return (access: ContactsAccess.unsupported, people: _empty);
    }
  }

  /// One row per number, newest phone formatting stripped off it. A contact
  /// with two numbers is two rows — the counter knows which one the car came
  /// in on, the app does not.
  static List<ContactPick> _tidy(List<Contact> raw) {
    final byPhone = <String, ContactPick>{};
    for (final c in raw) {
      final name = (c.displayName ?? '').trim();
      final email = c.emails.isEmpty ? '' : c.emails.first.address.trim();
      for (final p in c.phones) {
        final phone = mobile(p.normalizedNumber ?? p.number);
        if (phone.isEmpty || name.isEmpty) continue;
        byPhone.putIfAbsent(
          phone,
          () => (name: name, phone: phone, email: email),
        );
      }
    }
    final people = byPhone.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return people;
  }

  /// The phone's own permission page for this app.
  ///
  /// Wrapped here so a screen that needs it does not have to import
  /// `flutter_contacts` for one call — this class is meant to be the whole
  /// of what the console knows about the address book.
  static Future<bool> openSettings() async {
    if (!supported) return false;
    try {
      await FlutterContacts.permissions.openSettings();
      return true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// A saved number down to the ten digits the form takes. Contacts hold them
  /// as `+91 98765 43210`, `098765 43210`, `(98765) 43210` — all the same
  /// mobile, and all of it has to match what was typed at the counter.
  ///
  /// Anything shorter than ten digits is a landline or a short code; it is
  /// returned empty rather than half-filled into the mobile field.
  static String mobile(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return '';
    return digits.substring(digits.length - 10);
  }
}

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/marketplace.dart';
import 'auth_service.dart';

final marketplaceGatewayProvider =
    Provider<MarketplaceGateway>((ref) => MarketplaceGateway.instance);

const _uuid = Uuid();

/// Buying and selling parts.
///
/// Unlike the rest of the customer app there is no on-device mirror of any
/// of this: a request only means anything once the platform has it, and a
/// listing only means anything once somebody else can see it. So every
/// method here either reaches the backend or fails out loud.
///
/// The list methods return null when they could not ask. They used to hand
/// back an empty list, and a dropped connection then read as "Nothing
/// listed yet" — a screen confidently wrong about the marketplace rather
/// than one offering to try again.
class MarketplaceGateway {
  MarketplaceGateway._();

  static final MarketplaceGateway instance = MarketplaceGateway._();

  SupabaseClient? get _client =>
      AuthService.instance.enabled ? Supabase.instance.client : null;

  String? get _uid => AuthService.instance.userId;

  // -------------------------------------------------------------------------
  // Photos
  // -------------------------------------------------------------------------

  /// Uploads picked images and returns their public URLs.
  ///
  /// The path is `<uid>/<owner-id>/<n>.jpg`, which is what the storage policy
  /// checks: a person may only write inside the folder named after their own
  /// user id. A photo that fails to upload is skipped rather than failing the
  /// whole submission — a request with two of its three pictures is worth far
  /// more than no request at all. The callers count what came back against
  /// what was picked, and tell the customer about the difference.
  Future<List<String>> uploadPhotos(String ownerId, List<String> paths) async {
    final client = _client;
    final uid = _uid;
    if (client == null || uid == null || paths.isEmpty) return const [];

    final urls = <String>[];
    final bucket = client.storage.from('marketplace');
    for (var i = 0; i < paths.length; i++) {
      final local = paths[i];
      try {
        final ext = local.split('.').last.toLowerCase();
        final safe = ext == 'png' || ext == 'webp' ? ext : 'jpg';
        final key = '$uid/$ownerId/$i.$safe';
        await bucket.upload(
          key,
          File(local),
          fileOptions: FileOptions(
            upsert: true,
            contentType: 'image/${safe == 'jpg' ? 'jpeg' : safe}',
          ),
        );
        urls.add(bucket.getPublicUrl(key));
      } catch (e) {
        debugPrint('photo upload failed for $local: $e');
      }
    }
    return urls;
  }

  // -------------------------------------------------------------------------
  // Buy — "I need this part"
  // -------------------------------------------------------------------------

  /// The workshops a customer may address a request or a listing to.
  ///
  /// Name and city only. Comes from the database rather than a join here,
  /// so a garage nobody is allowed to see never reaches the picker.
  Future<List<({String id, String name, String city})>?> listableGarages()
      async {
    final client = _client;
    if (client == null) return null;
    try {
      final rows = await client.rpc('listable_garages') as List<dynamic>;
      return rows
          .map((r) => (
                id: (r['id'] ?? '').toString(),
                name: (r['name'] ?? '').toString(),
                city: (r['city'] ?? '').toString(),
              ))
          .where((g) => g.id.isNotEmpty)
          .toList(growable: false);
    } catch (e) {
      debugPrint('listable_garages failed: $e');
      return null;
    }
  }

  /// Files a request. Returns the quotable code on success, with how many of
  /// the picked photos could not be uploaded and went missing from it; null
  /// when nothing was filed.
  ///
  /// The code is minted by the database, never here: two phones offline at
  /// once would otherwise be able to pick the same one.
  Future<({String code, int photosFailed})?> createRequest({
    required String partName,
    String detail = '',
    String vehicleText = '',
    String? vehicleId,
    String? garageId,
    List<String> photoPaths = const [],
  }) async {
    final client = _client;
    if (client == null) return null;
    final id = _uuid.v4();
    try {
      final photos = await uploadPhotos(id, photoPaths);
      final res = await client
          .from('part_requests')
          .insert({
            'id': id,
            'part_name': partName.trim(),
            'detail': detail.trim(),
            'vehicle_text': vehicleText.trim(),
            'vehicle_id': vehicleId,
            'garage_id': garageId,
            'photos': photos,
          })
          .select('code')
          .single();
      final code = (res['code'] ?? '') as String;
      if (code.isEmpty) return null;
      return (code: code, photosFailed: photoPaths.length - photos.length);
    } catch (e) {
      debugPrint('createRequest failed: $e');
      return null;
    }
  }

  /// This customer's own requests, filtered here and not left to RLS.
  ///
  /// The policies are a union: a customer who also runs a workshop can read
  /// every request addressed to that workshop too, and without the filter
  /// those came back looking like requests they had filed themselves.
  Future<List<PartRequest>?> myRequests() async {
    final client = _client;
    final uid = _uid;
    if (client == null || uid == null) return null;
    try {
      final rows = await client
          .from('part_requests')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false);
      return rows
          .map((r) => PartRequest.fromJson(Map<String, dynamic>.from(r)))
          .toList(growable: false);
    } catch (e) {
      debugPrint('myRequests failed: $e');
      return null;
    }
  }

  // -------------------------------------------------------------------------
  // Sell
  // -------------------------------------------------------------------------

  /// Publishes a listing — into the review queue, not onto the browse screen.
  /// Returns how many of the picked photos could not be uploaded and went
  /// without, or null when the listing was not filed at all.
  Future<({int photosFailed})?> createListing({
    required String title,
    required double price,
    String detail = '',
    String partNo = '',
    PartCondition condition = PartCondition.used,
    String vehicleText = '',
    String? vehicleId,
    String city = '',
    String pin = '',
    String? garageId,
    List<String> photoPaths = const [],
  }) async {
    final client = _client;
    if (client == null) return null;
    final id = _uuid.v4();
    try {
      final photos = await uploadPhotos(id, photoPaths);
      await client.from('part_listings').insert({
        'id': id,
        'title': title.trim(),
        'detail': detail.trim(),
        'part_no': partNo.trim(),
        'condition': condition.wire,
        'price': price,
        'vehicle_text': vehicleText.trim(),
        'vehicle_id': vehicleId,
        'city': city.trim(),
        'pin': pin.trim(),
        'garage_id': garageId,
        'photos': photos,
      });
      return (photosFailed: photoPaths.length - photos.length);
    } catch (e) {
      debugPrint('createListing failed: $e');
      return null;
    }
  }

  /// What this customer is selling — theirs only.
  ///
  /// RLS alone is not a filter here: every signed-in person may read every
  /// approved listing, so an unfiltered select put the whole marketplace on
  /// the "Selling" tab as if this customer had posted it.
  Future<List<PartListing>?> myListings() async {
    final client = _client;
    final uid = _uid;
    if (client == null || uid == null) return null;
    try {
      final rows = await client
          .from('part_listings')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false);
      return rows
          .map((r) => PartListing.fromJson(Map<String, dynamic>.from(r)))
          .toList(growable: false);
    } catch (e) {
      debugPrint('myListings failed: $e');
      return null;
    }
  }

  /// The two moves a seller may make on their own listing. Approving is not
  /// one of them, and the database enforces that rather than this method.
  ///
  /// True only when a row actually changed: an update the row policy
  /// filters out is not an error to PostgREST, just nothing, and it used to
  /// come back as success.
  Future<bool> setListingStatus(String id, ListingStatus status) async {
    final client = _client;
    if (client == null) return false;
    if (status != ListingStatus.sold && status != ListingStatus.withdrawn) {
      return false;
    }
    try {
      final rows = await client
          .from('part_listings')
          .update({'status': status.name})
          .eq('id', id)
          .select('id');
      return rows.isNotEmpty;
    } catch (e) {
      debugPrint('setListingStatus failed: $e');
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // Browse
  // -------------------------------------------------------------------------

  /// What is for sale. Goes through `browse_listings()` rather than the table
  /// so a browsing customer never receives the seller's user id.
  Future<List<PartListing>?> browse({String query = '', int limit = 60}) async {
    final client = _client;
    if (client == null) return null;
    try {
      final res = await client.rpc('browse_listings', params: {
        'q': query.trim().isEmpty ? null : query.trim(),
        'max_rows': limit,
      });
      final rows = (res as List?) ?? const [];
      return rows
          .whereType<Map<String, dynamic>>()
          .map(PartListing.fromJson)
          .toList(growable: false);
    } catch (e) {
      debugPrint('browse failed: $e');
      return null;
    }
  }
}

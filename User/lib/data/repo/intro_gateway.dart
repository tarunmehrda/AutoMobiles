import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

final introGatewayProvider =
    Provider<IntroGateway>((ref) => IntroGateway.instance);

/// Which welcome video to play: the platform's own, when it has set one.
///
/// Deliberately forgiving: a project with no video, a video switched off, a
/// link that is not a video file and a backend that cannot be reached all
/// answer null, and the app plays the clip it ships with instead. Nothing
/// waits on this for longer than one small read.
class IntroGateway {
  IntroGateway._();

  static final IntroGateway instance = IntroGateway._();

  SupabaseClient? get _client =>
      AuthService.instance.enabled ? Supabase.instance.client : null;

  /// The link set under Platform → Content in the console, when it is
  /// switched on and points at something the player can open.
  Future<String?> overrideUrl() async {
    final client = _client;
    if (client == null) return null;
    try {
      final row = await client
          .from('platform_settings')
          .select('intro_video_url, intro_video_on')
          .eq('id', 1)
          .maybeSingle();
      if (row == null || row['intro_video_on'] != true) return null;
      final url = ((row['intro_video_url'] ?? '') as String).trim();
      return playable(url) ? url : null;
    } catch (e) {
      debugPrint('welcome video setting unavailable: $e');
      return null;
    }
  }

  /// A direct video file or stream. A YouTube page is a web page, and the
  /// in-app player shows a black box for it.
  static bool playable(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !uri.host.contains('.')) return false;
    final path = uri.path.toLowerCase();
    return path.endsWith('.mp4') || path.endsWith('.m3u8');
  }
}

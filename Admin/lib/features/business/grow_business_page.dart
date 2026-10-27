import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/g_field.dart';
import '../../core/widgets/g_surface.dart';
import '../../data/models/books.dart';
import '../../state/admin_state.dart';
import '../../state/providers.dart';

/// One of the workshop's channels: what it is called, how it is drawn, and
/// where in [SocialLinks] it is kept.
class _Channel {
  const _Channel(this.label, this.icon, this.tint, this.hint, this.read, this.write);

  final String label;
  final IconData icon;
  final Color tint;
  final String hint;
  final String Function(SocialLinks) read;
  final SocialLinks Function(SocialLinks, String) write;
}

final _channels = <_Channel>[
  _Channel(
    'WhatsApp Business',
    Icons.chat_rounded,
    const Color(0xFF25D366),
    '98765 43210',
    (s) => s.whatsapp,
    (s, v) => s.copyWith(whatsapp: v),
  ),
  _Channel(
    'Instagram',
    Icons.camera_alt_rounded,
    const Color(0xFFE1306C),
    'instagram.com/yourgarage',
    (s) => s.instagram,
    (s, v) => s.copyWith(instagram: v),
  ),
  _Channel(
    'Facebook',
    Icons.facebook_rounded,
    const Color(0xFF1877F2),
    'facebook.com/yourgarage',
    (s) => s.facebook,
    (s, v) => s.copyWith(facebook: v),
  ),
  _Channel(
    'YouTube',
    Icons.smart_display_rounded,
    const Color(0xFFFF0000),
    'youtube.com/@yourgarage',
    (s) => s.youtube,
    (s, v) => s.copyWith(youtube: v),
  ),
  _Channel(
    'Google reviews',
    Icons.reviews_rounded,
    const Color(0xFFF2B01E),
    'g.page/r/… (your review link)',
    (s) => s.google,
    (s, v) => s.copyWith(google: v),
  ),
  _Channel(
    'Website',
    Icons.language_rounded,
    const Color(0xFF5B6CFF),
    'www.yourgarage.in',
    (s) => s.website,
    (s, v) => s.copyWith(website: v),
  ),
];

/// "Grow your business": the workshop's social media in one place, and the
/// two things that actually bring cars in — a post worth sharing, and a
/// review link in a happy customer's hand.
class GrowBusinessPage extends ConsumerWidget {
  const GrowBusinessPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.c;
    final social = ref.watch(adminProvider.select((d) => d.social));
    final garage = ref.watch(garageProvider);
    final bookText = ref.watch(onlineShareTextProvider);
    final linked = _channels.where((c) => c.read(social).trim().isNotEmpty);

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Grow your business'.tr,
        subtitle: 'Social media, reviews & offers'.tr,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.h2),
        children: [
          _Hero(linked: linked.length, total: _channels.length),
          const SizedBox(height: Gap.xl),

          // --- the channels --------------------------------------------
          GTileGroup(
            title: 'Social media'.tr,
            children: [
              for (final c in _channels)
                GTile(
                  leading: Container(
                    height: 42,
                    width: 42,
                    decoration: BoxDecoration(
                      color: c.tint.withValues(alpha: p.isDark ? 0.2 : 0.12),
                      borderRadius: R.all(R.md),
                    ),
                    child: Icon(c.icon, size: 21, color: c.tint),
                  ),
                  title: c.label.tr,
                  subtitle: c.read(social).isEmpty
                      ? 'Not linked — tap to add'.tr
                      : c.read(social),
                  trailing: c.read(social).isEmpty
                      ? Icon(Icons.add_circle_rounded, color: p.accent)
                      : IconButton(
                          tooltip: 'Open'.tr,
                          onPressed: () => _open(context, c, c.read(social)),
                          icon: Icon(
                            Icons.open_in_new_rounded,
                            size: 20,
                            color: p.inkMuted,
                          ),
                        ),
                  onTap: () => _edit(context, ref, c, social),
                ),
            ],
          ),
          const SizedBox(height: Gap.xl),

          // --- things to do with them -----------------------------------
          GTileGroup(
            title: 'Share & promote'.tr,
            children: [
              GTile(
                icon: Icons.campaign_rounded,
                iconColor: p.accent,
                title: 'Share your workshop'.tr,
                subtitle: 'A ready post with your services and links'.tr,
                onTap: () => _share(
                  _promoPost(garage?.name ?? '', garage?.phone ?? '', social, bookText),
                ),
              ),
              if (social.google.trim().isNotEmpty)
                GTile(
                  icon: Icons.star_rounded,
                  iconColor: const Color(0xFFF2B01E),
                  title: 'Ask for a Google review'.tr,
                  subtitle: 'Send your review link to a happy customer'.tr,
                  onTap: () => _share(
                    'Thank you for choosing {0}! It would mean a lot if you could rate us on Google: {1}'
                        .trf([garage?.name ?? 'us'.tr, social.google.trim()]),
                  ),
                ),
              if (bookText.isNotEmpty)
                GTile(
                  icon: Icons.event_available_rounded,
                  iconColor: p.info,
                  title: 'Share your booking link'.tr,
                  subtitle: 'Customers book a slot from their phone'.tr,
                  onTap: () => _share(bookText),
                ),
              GTile(
                icon: Icons.local_offer_rounded,
                iconColor: p.success,
                title: 'Greetings & offers'.tr,
                subtitle: 'Festival wishes and discounts by SMS'.tr,
                onTap: () => context.push('/settings/greetings'),
              ),
              GTile(
                icon: Icons.storefront_rounded,
                iconColor: p.warning,
                title: 'Online garage'.tr,
                subtitle: 'Your service menu in the customer app'.tr,
                onTap: () => context.push('/online-garage'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Future<void> _share(String text) =>
      SharePlus.instance.share(ShareParams(text: text));

  /// A post that reads like the workshop wrote it, with every channel it
  /// has linked so a share on one network leads to the others.
  static String _promoPost(
    String name,
    String phone,
    SocialLinks s,
    String booking,
  ) {
    final lines = <String>[
      '🚗 ${name.isEmpty ? 'Our workshop'.tr : name}',
      'Car service, repairs, denting & painting, AC, electricals — done right, on time.'
          .tr,
      if (phone.isNotEmpty) '📞 $phone',
      if (s.whatsapp.isNotEmpty) '💬 WhatsApp: ${_waLink(s.whatsapp)}',
      if (s.instagram.isNotEmpty) '📸 ${s.instagram}',
      if (s.facebook.isNotEmpty) '👍 ${s.facebook}',
      if (s.youtube.isNotEmpty) '▶️ ${s.youtube}',
      if (s.website.isNotEmpty) '🌐 ${s.website}',
      if (s.google.isNotEmpty) '⭐ ${s.google}',
      if (booking.isNotEmpty) '',
      if (booking.isNotEmpty) booking,
    ];
    return lines.join('\n');
  }

  static String _waLink(String number) {
    final digits = number.replaceAll(RegExp(r'\D'), '');
    final full = digits.length == 10 ? '91$digits' : digits;
    return 'https://wa.me/$full';
  }

  static Uri? _uriFor(_Channel c, String value) {
    final v = value.trim();
    if (v.isEmpty) return null;
    if (c.label == 'WhatsApp Business') return Uri.parse(_waLink(v));
    return Uri.tryParse(v.startsWith('http') ? v : 'https://$v');
  }

  static Future<void> _open(
    BuildContext context,
    _Channel c,
    String value,
  ) async {
    final uri = _uriFor(c, value);
    final ok =
        uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      GFeedback.error(context, 'Could not open that link'.tr);
    }
  }

  static Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    _Channel c,
    SocialLinks current,
  ) async {
    final field = TextEditingController(text: c.read(current));
    await GFeedback.sheet<void>(
      context,
      title: c.label.tr,
      subtitle: 'Shown on your shared posts'.tr,
      disposing: [field],
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Gap.page,
          Gap.lg,
          Gap.page,
          MediaQuery.of(context).viewInsets.bottom + Gap.h1,
        ),
        child: Builder(
          builder: (context) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GField(
                label: c.label == 'WhatsApp Business'
                    ? 'Number'.tr
                    : 'Link'.tr,
                hint: c.hint,
                controller: field,
                autofocus: true,
                keyboardType: c.label == 'WhatsApp Business'
                    ? TextInputType.phone
                    : TextInputType.url,
                textCapitalization: TextCapitalization.none,
              ),
              const SizedBox(height: Gap.xl),
              Row(
                children: [
                  if (c.read(current).isNotEmpty) ...[
                    Expanded(
                      child: GButton(
                        label: 'Remove'.tr,
                        kind: GButtonKind.danger,
                        size: GButtonSize.md,
                        onPressed: () {
                          ref
                              .read(adminProvider.notifier)
                              .setSocial(c.write(current, ''));
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                    const SizedBox(width: Gap.md),
                  ],
                  Expanded(
                    flex: 2,
                    child: GButton.accent(
                      label: 'Save'.tr,
                      size: GButtonSize.md,
                      onPressed: () {
                        ref
                            .read(adminProvider.notifier)
                            .setSocial(c.write(current, field.text.trim()));
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.linked, required this.total});

  final int linked;
  final int total;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(p.accent, Colors.white, 0.06)!,
            Color.lerp(p.accent, Colors.black, 0.3)!,
          ],
        ),
        borderRadius: R.all(R.xl),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Be found. Be trusted.'.tr,
                  style: AppType.h1.s(20).c(Colors.white).w(FontWeight.w800),
                ),
                const SizedBox(height: Gap.xs),
                Text(
                  'Most customers pick a workshop from a friend\'s share or a Google review. Link your pages, then share them in a tap.'
                      .tr,
                  style: AppType.bodyS.c(Colors.white.withValues(alpha: 0.9)),
                ),
                const SizedBox(height: Gap.md),
                Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Gap.md,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: R.all(R.pill),
                    ),
                    child: Text(
                      '{0} of {1} linked'.trf([linked, total]),
                      style: AppType.labelS.c(Colors.white),
                    ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Gap.md),
          const Icon(Icons.campaign_rounded, size: 56, color: Colors.white),
        ],
      ),
    );
  }
}

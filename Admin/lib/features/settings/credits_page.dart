import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/g_field.dart';
import '../../core/widgets/g_state.dart';
import '../../core/widgets/pressable.dart';
import '../../data/seed/image_credits.dart';
import '../../data/seed/part_media.dart';

/// Who took the photographs this app shows.
///
/// This screen is not a nicety. The vehicle photography is largely Wikimedia
/// Commons material under CC BY and CC BY-SA, and both licences make naming
/// the author a *condition* of using the work — shipping the pictures without
/// a credit the user can actually reach is a breach of the licence, not a
/// missing polish item.
///
/// So it is deliberately plain and complete: every file, its subject, its
/// author, its licence, and a link to the original page where the full terms
/// live. The search box is there because the list runs to hundreds of rows
/// and somebody checking one specific picture should not have to scroll.
///
/// The catalogue photography in [PartMedia] is fetched over the network
/// rather than bundled, which changes nothing about the obligation: the app
/// still puts those pictures in front of a user, so it still has to say whose
/// they are. Both sets appear here, in one list.
class CreditsPage extends StatefulWidget {
  const CreditsPage({super.key});

  @override
  State<CreditsPage> createState() => _CreditsPageState();
}

class _CreditsPageState extends State<CreditsPage> {
  final _search = TextEditingController();

  /// The bundled vehicle photography and the fetched catalogue photography,
  /// as one list. Built once per screen rather than per keystroke — the
  /// search rebuilds this list on every character typed into it.
  late final List<ImageCredit> _all = [
    ...kImageCredits,
    for (final photo in PartMedia.credits)
      (
        subject: 'Catalogue · ${photo.subject}',
        author: photo.author,
        licence: photo.licence,
        source: photo.source,
      ),
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Image credits'.tr,
        subtitle: 'Who took the photographs in this app'.tr,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Gap.page,
              Gap.md,
              Gap.page,
              Gap.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The vehicle photographs come from Wikimedia Commons and from Unsplash. Most are published under a Creative Commons licence that asks for the photographer to be named, which is what this page does. Tap a row to open the original.'
                      .tr,
                  style: AppType.bodyM.c(p.inkSoft),
                ),
                const SizedBox(height: Gap.md),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _search,
                  builder: (context, value, child) => child!,
                  child: GSearchBar(
                    hint: 'Search a vehicle or a photographer'.tr,
                    controller: _search,
                    onClear: _search.clear,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _search,
              builder: (context, value, _) => _list(value.text.trim()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(String raw) {
    final p = context.c;
    final q = raw.toLowerCase();
    final rows = q.isEmpty
        ? _all
        : [
            for (final c in _all)
              if (c.subject.toLowerCase().contains(q) ||
                  c.author.toLowerCase().contains(q) ||
                  c.licence.toLowerCase().contains(q))
                c,
          ];

    if (rows.isEmpty) {
      return GEmptyState(
        compact: true,
        icon: Icons.search_off_rounded,
        title: 'No match'.tr,
        message: 'Nothing here by that name.'.tr,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.h2),
      itemCount: rows.length + 1,
      itemBuilder: (context, i) {
        if (i == rows.length) {
          return Padding(
            padding: const EdgeInsets.only(top: Gap.lg),
            child: Text(
              '{0} of {1} photographs. The rest of the artwork — the marque badges and the illustrations — is public domain or licensed without an attribution requirement.'
                  .trf([rows.length, _all.length]),
              style: AppType.labelS.c(p.inkFaint),
            ),
          );
        }
        return _Row(credit: rows[i]);
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.credit});

  final ImageCredit credit;

  Future<void> _open() async {
    final uri = Uri.tryParse(credit.source);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      onTap: credit.source.isEmpty ? null : _open,
      scale: 0.99,
      child: Container(
        margin: const EdgeInsets.only(bottom: Gap.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.lg,
          vertical: Gap.md,
        ),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: R.rMd,
          border: Border.all(color: p.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    credit.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.labelL.c(p.ink),
                  ),
                  Text(
                    credit.author,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.bodyS.c(p.inkMuted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    credit.licence,
                    style: AppType.labelS.s(10).c(p.accentInk),
                  ),
                ],
              ),
            ),
            if (credit.source.isNotEmpty)
              Icon(Icons.open_in_new_rounded, size: 15, color: p.inkFaint),
          ],
        ),
      ),
    );
  }
}

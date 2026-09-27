import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/widgets/g_button.dart';
import '../../../core/widgets/g_feedback.dart';
import '../../../core/widgets/g_field.dart';
import '../../../data/repo/platform_gateway.dart';

/// The welcome video both apps play when a signed-in person opens them.
///
/// It changes without a release, which is the point: a video URL baked into
/// an APK means waiting on a Play Store review to swap a clip. (The default
/// commission used to sit here too; it lives with the rest of the commission
/// under Settings → Commission now, so there is one place it is set.)
class ContentSection extends ConsumerStatefulWidget {
  const ContentSection({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  final PlatformSettings settings;
  final Future<void> Function() onChanged;

  @override
  ConsumerState<ContentSection> createState() => _ContentSectionState();
}

class _ContentSectionState extends ConsumerState<ContentSection> {
  late final TextEditingController _url =
      TextEditingController(text: widget.settings.introVideoUrl);

  late bool _on = widget.settings.introVideoOn;
  bool _busy = false;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  /// A URL the video player can actually open. A YouTube watch page is the
  /// mistake to catch here: it is a web page, not a video file, and the
  /// in-app player shows a black rectangle for it with no error worth
  /// reading.
  String? get _urlProblem {
    final raw = _url.text.trim();
    if (raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme || !uri.host.contains('.')) {
      return 'That does not look like a web address.';
    }
    if (uri.host.contains('youtube.') || uri.host.contains('youtu.be')) {
      return 'A YouTube page will not play in the app. Upload the .mp4 and '
          'paste its direct link.';
    }
    if (!uri.path.toLowerCase().endsWith('.mp4') &&
        !uri.path.toLowerCase().endsWith('.m3u8')) {
      return 'This should be a direct link to an .mp4 or an .m3u8 stream.';
    }
    return null;
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final error = await ref.read(platformGatewayProvider).saveSettings(
          introVideoUrl: _url.text.trim(),
          introVideoOn: _on,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      GFeedback.error(context, error);
      return;
    }
    GFeedback.success(context, 'Saved.');
    await widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final problem = _urlProblem;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.h3),
      children: [
        Text('Welcome video', style: AppType.h3.c(p.ink)),
        const SizedBox(height: Gap.xs),
        Text(
          'Plays in a corner box each time someone signed in opens either '
          'app — customers and the workshop console. They can watch it full '
          'screen, minimise it or close it. With no link here, both apps play '
          'the workshop clip they ship with.',
          style: AppType.bodyS.c(p.inkMuted),
        ),
        const SizedBox(height: Gap.lg),
        GField(
          label: 'Video link',
          hint: 'https://…/welcome.mp4',
          controller: _url,
          keyboardType: TextInputType.url,
          textCapitalization: TextCapitalization.none,
          onChanged: (_) => setState(() {}),
        ),
        if (problem != null) ...[
          const SizedBox(height: Gap.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline_rounded, size: 15, color: p.warning),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(problem, style: AppType.bodyS.c(p.warning)),
              ),
            ],
          ),
        ],
        const SizedBox(height: Gap.lg),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: Gap.lg, vertical: Gap.sm),
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
                    Text('Use this video instead',
                        style: AppType.bodyM.c(p.ink)),
                    Text(
                      _on
                          ? 'On — both apps play this link'
                          : 'Off — both apps play the built-in clip',
                      style: AppType.labelS.c(p.inkMuted),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _on,
                onChanged: _url.text.trim().isEmpty
                    ? null
                    : (v) => setState(() => _on = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: Gap.sm),
        Text(
          'Turning this off keeps the link, so it can be switched back on '
          'without pasting it again.',
          style: AppType.labelS.c(p.inkFaint),
        ),

        const SizedBox(height: Gap.h2),
        GButton(
          label: 'Save',
          loading: _busy,
          onPressed: _busy ? null : _save,
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/g_appbar.dart';
import '../../core/widgets/local_image.dart';
import '../../core/widgets/g_badge.dart';
import '../../core/widgets/g_button.dart';
import '../../core/widgets/g_feedback.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/entities.dart';
import '../../data/repo/demo_seed.dart';
import '../../data/seed/catalog_seed.dart';
import '../../state/app_state.dart';
import '../../state/providers.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  String _topic = Seed.chatTopics.first;
  bool _awaitingReply = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? preset]) {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty) return;
    _input.clear();
    ref.read(appControllerProvider.notifier).sendChat(text, topic: _topic);
    setState(() => _awaitingReply = true);
    _scrollDown();
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _awaitingReply = false);
    });
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 120,
        duration: Motion.base,
        curve: Motion.enter,
      );
    });
  }

  Future<void> _attach() async {
    try {
      final picked = await ImagePicker()
          .pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (picked == null || !mounted) return;
      ref.read(appControllerProvider.notifier).sendChat(
            'Sent a photo',
            topic: _topic,
            imagePath: picked.path,
          );
      _scrollDown();
    } catch (_) {
      if (mounted) {
        GFeedback.error(context, 'Could not open the gallery on this device');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final messages = ref.watch(chatProvider);

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: DemoSeed.advisor,
        subtitle: 'Service advisor • usually replies in minutes',
        actions: [
          GIconButton(
            icon: Icons.call_rounded,
            size: 40,
            onTap: () async {
              final uri = Uri.parse('tel:${Seed.garage.phone}');
              if (await canLaunchUrl(uri)) await launchUrl(uri);
            },
          ),
        ],
        bottom: Padding(
          padding: const EdgeInsets.only(bottom: Gap.md),
          child: GChoiceChips<String>(
            options: Seed.chatTopics,
            selected: _topic,
            onSelect: (t) => setState(() => _topic = t),
            labelOf: (t) => t,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? _empty(p)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(
                        Gap.page, Gap.md, Gap.page, Gap.lg),
                    itemCount: messages.length + (_awaitingReply ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == messages.length) return const _Typing();
                      final m = messages[i];
                      final showDay = i == 0 ||
                          !_sameDay(messages[i - 1].at, m.at);
                      return Column(
                        children: [
                          if (showDay)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: Gap.md),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: Gap.md, vertical: 4),
                                decoration: BoxDecoration(
                                  color: p.surfaceSunken,
                                  borderRadius: R.all(R.pill),
                                ),
                                child: Text(Fmt.friendlyDay(m.at),
                                    style: AppType.labelS.c(p.inkMuted)),
                              ),
                            ),
                          _Bubble(message: m),
                        ],
                      );
                    },
                  ),
          ),

          // --- quick replies -----------------------------------------
          if (messages.isEmpty || messages.last.fromMe == false)
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Gap.page),
                children: [
                  for (final q in _quickReplies)
                    Padding(
                      padding: const EdgeInsets.only(right: Gap.sm),
                      child: Pressable(
                        onTap: () => _send(q),
                        scale: 0.94,
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: Gap.md),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: p.surface,
                            borderRadius: R.all(R.pill),
                            border: Border.all(color: p.line),
                          ),
                          child: Text(q,
                              style: AppType.labelS.c(p.accentInk)),
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // --- composer ------------------------------------------------
          Container(
            decoration: BoxDecoration(
              color: p.surface,
              border: Border(top: BorderSide(color: p.line)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    Gap.md, Gap.sm, Gap.md, Gap.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    GIconButton(
                      icon: Icons.add_photo_alternate_outlined,
                      size: 44,
                      bordered: false,
                      background: p.surfaceSunken,
                      onTap: _attach,
                    ),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 120),
                        decoration: BoxDecoration(
                          color: p.surfaceSunken,
                          borderRadius: R.all(R.lg),
                          border: Border.all(color: p.line),
                        ),
                        child: TextField(
                          controller: _input,
                          minLines: 1,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          style: AppType.bodyM.c(p.ink),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            hintText: 'Message about $_topic…',
                            hintStyle: AppType.bodyM.c(p.inkFaint),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: Gap.lg, vertical: Gap.md),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    Pressable(
                      onTap: _input.text.trim().isEmpty ? null : _send,
                      enabled: _input.text.trim().isNotEmpty,
                      scale: 0.9,
                      child: AnimatedContainer(
                        duration: Motion.fast,
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(
                          gradient: _input.text.trim().isEmpty
                              ? null
                              : p.accentGradient,
                          color: _input.text.trim().isEmpty
                              ? p.surfaceSunken
                              : null,
                          borderRadius: R.all(R.md),
                        ),
                        child: Icon(
                          Icons.arrow_upward_rounded,
                          size: 20,
                          color: _input.text.trim().isEmpty
                              ? p.inkFaint
                              : p.onAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _quickReplies = [
    'What is the status?',
    'Can I get it today?',
    'Explain this charge',
    'Call me please',
  ];

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _empty(AppPalette p) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.h1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GAvatar(
              initials: Fmt.initials(DemoSeed.advisor),
              size: 64,
              tone: GTone.accent,
            ),
            const SizedBox(height: Gap.lg),
            Text('Say hello to ${DemoSeed.advisor.split(' ').first}',
                style: AppType.h1.c(p.ink)),
            const SizedBox(height: Gap.sm),
            Text(
              'Ask about a booking, an estimate line or the pickup — anything '
              'at all. Photos are welcome.',
              textAlign: TextAlign.center,
              style: AppType.bodyM.c(p.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final mine = message.fromMe;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: Gap.sm),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.sm),
        decoration: BoxDecoration(
          color: mine ? p.ink : p.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(R.lg),
            topRight: const Radius.circular(R.lg),
            bottomLeft: Radius.circular(mine ? R.lg : 5),
            bottomRight: Radius.circular(mine ? 5 : R.lg),
          ),
          border: mine ? null : Border.all(color: p.line),
          boxShadow: mine ? null : Shadows.soft(p),
        ),
        child: Column(
          crossAxisAlignment:
              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!mine && message.author != null) ...[
              Text(message.author!,
                  style: AppType.labelS.c(p.accentInk)),
              const SizedBox(height: 3),
            ],
            if (message.imagePath != null) ...[
              ClipRRect(
                borderRadius: R.all(R.sm),
                child: localImage(
                  message.imagePath!,
                  height: 160,
                  fallback: () => Container(
                    height: 80,
                    width: 160,
                    color: p.surfaceSunken,
                    child: Icon(Icons.broken_image_rounded, color: p.inkFaint),
                  ),
                ),
              ),
              const SizedBox(height: Gap.sm),
            ],
            Text(
              message.text,
              style: AppType.bodyM.c(
                  mine ? (p.isDark ? p.canvas : Colors.white) : p.inkSoft),
            ),
            const SizedBox(height: 3),
            Text(
              Fmt.time(message.at),
              style: AppType.labelS.s(9.5).c(mine
                  ? (p.isDark ? p.canvas : Colors.white)
                      .withValues(alpha: 0.5)
                  : p.inkFaint),
            ),
          ],
        ),
      ),
    );
  }
}

class _Typing extends StatefulWidget {
  const _Typing();

  @override
  State<_Typing> createState() => _TypingState();
}

class _TypingState extends State<_Typing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: Gap.sm),
        padding:
            const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(R.lg),
            topRight: Radius.circular(R.lg),
            bottomRight: Radius.circular(R.lg),
            bottomLeft: Radius.circular(5),
          ),
          border: Border.all(color: p.line),
        ),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++) ...[
                Opacity(
                  opacity: 0.35 +
                      0.65 *
                          ((((_c.value * 3) - i) % 3).clamp(0.0, 1.0)),
                  child: Container(
                    height: 6,
                    width: 6,
                    decoration: BoxDecoration(
                        color: p.inkMuted, shape: BoxShape.circle),
                  ),
                ),
                if (i != 2) const SizedBox(width: 4),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

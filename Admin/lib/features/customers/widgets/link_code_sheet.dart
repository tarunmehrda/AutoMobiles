import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/widgets/g_button.dart';
import '../../../core/widgets/g_feedback.dart';
import '../../../data/repo/garage_gateway.dart';

/// Hands a customer the key to their own service history.
///
/// A phone number is not proof of anything — anybody could type it into
/// their app and walk off with somebody else's records. So the workshop
/// vouches instead: this issues a six-digit code against one customer
/// record, good for a day and burnt on first use. Read it out at the
/// counter; whoever types it into the customer app gets that record's job
/// cards, live, and nothing else.
class LinkCodeSheet extends StatefulWidget {
  const LinkCodeSheet({super.key, required this.customerId, this.name = ''});

  final String customerId;
  final String name;

  static Future<void> open(
    BuildContext context, {
    required String customerId,
    String name = '',
  }) =>
      GFeedback.sheet<void>(
        context,
        title: 'Link to the customer app',
        subtitle: name.isEmpty ? null : 'For $name',
        child: LinkCodeSheet(customerId: customerId, name: name),
      );

  @override
  State<LinkCodeSheet> createState() => _LinkCodeSheetState();
}

class _LinkCodeSheetState extends State<LinkCodeSheet> {
  String? _code;
  String? _problem;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _issue();
  }

  Future<void> _issue() async {
    setState(() {
      _busy = true;
      _problem = null;
    });
    final code = await GarageGateway.instance.issueLinkCode(widget.customerId);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _code = code;
      _problem = code == null
          ? 'Could not reach the backend. Check the network and try again.'
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.page),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Read this out to the customer. They enter it under '
            '"Link your workshop" in their app, and every job card you open '
            'for them shows up there as you work.',
            style: AppType.bodyS.c(p.inkSoft),
          ),
          const SizedBox(height: Gap.xl),
          Container(
            padding: const EdgeInsets.symmetric(vertical: Gap.xl),
            decoration: BoxDecoration(
              color: p.surfaceAlt,
              borderRadius: R.all(R.lg),
              border: Border.all(color: p.line),
            ),
            child: Center(
              child: _busy
                  ? SizedBox(
                      height: 30,
                      width: 30,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: p.accent),
                    )
                  : Text(
                      _code ?? '——————',
                      style: AppType.d2.copyWith(
                        color: p.ink,
                        letterSpacing: 10,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
            ),
          ),
          if (_problem != null) ...[
            const SizedBox(height: Gap.sm),
            Text(_problem!, style: AppType.labelM.c(p.danger)),
          ] else ...[
            const SizedBox(height: Gap.sm),
            Text('Valid for 24 hours, and only once.',
                textAlign: TextAlign.center,
                style: AppType.labelS.c(p.inkFaint)),
          ],
          const SizedBox(height: Gap.lg),
          if (_code != null)
            GButton(
              label: 'Copy code',
              kind: GButtonKind.ghost,
              icon: Icons.copy_rounded,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: _code!));
                if (context.mounted) GFeedback.success(context, 'Copied');
              },
            )
          else if (!_busy)
            GButton(label: 'Try again', onPressed: _issue),
        ],
      ),
    );
  }
}

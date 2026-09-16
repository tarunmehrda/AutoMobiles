import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/widgets/g_button.dart';
import '../../../core/widgets/g_feedback.dart';
import '../../../core/widgets/g_field.dart';
import '../../../state/app_state.dart';

/// Claims the workshop's record of you, using the code they read out at the
/// counter.
///
/// A phone number alone is not proof — anyone could type yours. The workshop
/// issues a code against one customer record, it lasts a day, and it burns on
/// first use, so the only person who gets your service history is the one the
/// workshop actually handed it to.
class LinkWorkshopSheet extends ConsumerStatefulWidget {
  const LinkWorkshopSheet({super.key});

  /// Opens the sheet and returns true if a workshop was linked.
  static Future<bool> open(BuildContext context) async =>
      await GFeedback.sheet<bool>(
        context,
        title: 'Link your workshop',
        subtitle: 'Ask the counter for your six-digit code',
        child: const LinkWorkshopSheet(),
      ) ??
      false;

  @override
  ConsumerState<LinkWorkshopSheet> createState() => _LinkWorkshopSheetState();
}

class _LinkWorkshopSheetState extends ConsumerState<LinkWorkshopSheet> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _problem;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _code.text.trim();
    if (code.length != 6 || _busy) return;

    setState(() {
      _busy = true;
      _problem = null;
    });

    final problem =
        await ref.read(appControllerProvider.notifier).redeemWorkshopCode(code);
    if (!mounted) return;

    if (problem != null) {
      setState(() {
        _busy = false;
        _problem = problem;
      });
      return;
    }

    Navigator.of(context).pop(true);
    GFeedback.success(context, 'Workshop linked. Your job cards are here.');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;

    return Padding(
      padding: EdgeInsets.fromLTRB(Gap.page, 0, Gap.page,
          MediaQuery.of(context).viewInsets.bottom + Gap.page),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Once it is linked, every job card that workshop opens for your '
            'car shows up here on its own — live, while the work is going on.',
            style: AppType.bodyS.copyWith(color: p.inkSoft),
          ),
          const SizedBox(height: Gap.xl),
          GField(
            label: 'Code',
            hint: '000000',
            controller: _code,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            enabled: !_busy,
            onChanged: (_) {
              if (_problem != null) setState(() => _problem = null);
            },
            onSubmitted: (_) => _submit(),
          ),
          if (_problem != null) ...[
            const SizedBox(height: Gap.sm),
            Text(_problem!, style: AppType.labelM.copyWith(color: p.danger)),
          ],
          const SizedBox(height: Gap.lg),
          GButton(
            label: 'Link workshop',
            loading: _busy,
            onPressed: _busy ? null : _submit,
          ),
        ],
      ),
    );
  }
}

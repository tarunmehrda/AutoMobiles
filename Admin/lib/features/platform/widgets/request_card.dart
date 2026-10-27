import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/g_badge.dart';
import '../../../core/widgets/g_feedback.dart';
import '../../../core/widgets/g_net_image.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/repo/platform_gateway.dart';
import '../platform_page.dart' show toneForStatus;

const _states = ['pending', 'processing', 'completed', 'cancelled'];

/// One "I need this part", with its code, and the two things the platform
/// does to it: move it along, and put a price on it.
class RequestCard extends ConsumerStatefulWidget {
  const RequestCard({
    super.key,
    required this.request,
    required this.garages,
    required this.onChanged,
  });

  final PlatformRequest request;
  final List<RegisteredGarage> garages;
  final Future<void> Function() onChanged;

  @override
  ConsumerState<RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends ConsumerState<RequestCard> {
  bool _busy = false;

  Future<void> _update({String? status, double? quote, String? note}) async {
    setState(() => _busy = true);
    final error = await ref.read(platformGatewayProvider).updateRequest(
          widget.request.id,
          status: status,
          quote: quote,
          note: note,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      GFeedback.error(context, error);
      return;
    }
    await widget.onChanged();
  }

  Future<void> _quote() async {
    final r = widget.request;
    final price = TextEditingController(text: r.quote?.toString() ?? '');
    final note = TextEditingController(text: r.note);

    final saved = await GFeedback.sheet<bool>(
      context,
      title: 'Quote ${r.code}',
      subtitle: r.partName,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.h1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: price,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Price',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: Gap.lg),
            TextField(
              controller: note,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Note to the customer',
                hintText: 'Availability, lead time, original or aftermarket',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: Gap.xl),
            Builder(
              builder: (context) => FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Save quote'),
              ),
            ),
          ],
        ),
      ),
    );

    final value = double.tryParse(price.text.trim());
    final text = note.text;
    price.dispose();
    note.dispose();

    if (saved == true) {
      await _update(
        quote: value,
        note: text,
        // Quoting something that was still sitting in the queue moves it on
        // by itself: nobody prices a request they have not started.
        status: widget.request.status == 'pending' ? 'processing' : null,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final r = widget.request;

    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: R.rLg,
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // The code, first and monospaced-looking, because every phone
              // call about this row opens with it.
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Gap.md, vertical: Gap.xs),
                  decoration: BoxDecoration(
                    color: p.surfaceSunken,
                    borderRadius: R.rSm,
                    border: Border.all(color: p.line),
                  ),
                  child: Text(
                    r.code,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.labelM.c(p.ink),
                  ),
                ),
              ),
              const SizedBox(width: Gap.sm),
              GPill(
                label: r.status,
                tone: toneForStatus(r.status),
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          Text(
            r.partName.isEmpty ? 'Part request' : r.partName,
            style: AppType.h3.c(p.ink),
          ),
          if (r.vehicleText.isNotEmpty) ...[
            const SizedBox(height: Gap.xxs),
            Text(r.vehicleText, style: AppType.bodyS.c(p.inkMuted)),
          ],
          if (r.detail.isNotEmpty) ...[
            const SizedBox(height: Gap.sm),
            Text(r.detail, style: AppType.bodyS.c(p.inkSoft)),
          ],

          if (r.photos.isNotEmpty) ...[
            const SizedBox(height: Gap.md),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: r.photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: Gap.sm),
                itemBuilder: (context, i) => GNetImage(
                  url: r.photos[i],
                  fallbackIcon: Icons.broken_image_outlined,
                  radius: R.sm,
                  height: 64,
                  width: 64,
                ),
              ),
            ),
          ],

          if (r.quote != null) ...[
            const SizedBox(height: Gap.md),
            Row(
              children: [
                Text('Quoted', style: AppType.labelS.c(p.inkMuted)),
                const SizedBox(width: Gap.sm),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      Fmt.money(r.quote!),
                      style: AppType.money.c(p.success),
                    ),
                  ),
                ),
              ],
            ),
          ],

          const Divider(height: Gap.xxl),

          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _states.length,
                    separatorBuilder: (_, _) => const SizedBox(width: Gap.xs),
                    itemBuilder: (context, i) {
                      final s = _states[i];
                      final on = r.status == s;
                      return Pressable(
                        enabled: !_busy && !on,
                        onTap: () => _update(status: s),
                        scale: 0.96,
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: Gap.md),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: on ? p.accent : p.surfaceSunken,
                            borderRadius: R.all(R.pill),
                            border:
                                Border.all(color: on ? p.accent : p.line),
                          ),
                          child: Text(
                            s,
                            style: AppType.labelS
                                .c(on ? p.onAccent : p.inkMuted),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: Gap.sm),
              Pressable(
                enabled: !_busy,
                onTap: _quote,
                scale: 0.94,
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p.inverse,
                    borderRadius: R.all(R.pill),
                  ),
                  child: Text('Quote',
                      style: AppType.labelS.c(p.onInverse)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

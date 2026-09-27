import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/widgets/brand_logo.dart';

/// Shown for the moment between signing in and this account arriving back
/// from the backend.
///
/// It exists so the router never has to guess. Deciding whether somebody
/// still needs a profile and a vehicle, while the answer is halfway down the
/// wire, is what used to skip the sign-up steps for a returning customer.
class RestoringPage extends StatelessWidget {
  const RestoringPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Scaffold(
      backgroundColor: p.canvas,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandBadge(size: 64),
            const SizedBox(height: Gap.xl),
            Text('Getting your garage', style: AppType.h1.c(p.ink)),
            const SizedBox(height: Gap.sm),
            Text('Fetching your vehicles and bookings…',
                style: AppType.bodyM.c(p.inkMuted)),
            const SizedBox(height: Gap.xl),
            SizedBox(
              width: 120,
              child: ClipRRect(
                borderRadius: R.all(R.pill),
                child: LinearProgressIndicator(
                  minHeight: 4,
                  backgroundColor: p.line,
                  valueColor: AlwaysStoppedAnimation(p.accent),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

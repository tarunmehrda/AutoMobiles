/// Picking the photographs that go on a card, in one place.
///
/// The counter reaches for these from two directions — the photos panel of a
/// card already open, and the details step while the card is still being
/// written — and both need the same camera gate and the same move out of the
/// picker's cache, so neither owns the logic.
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/utils/save_file.dart';
import '../../../core/widgets/g_button.dart';
import '../../../core/widgets/g_feedback.dart';
import '../../../core/widgets/local_image.dart';
import '../../../core/widgets/pressable.dart';

/// The manifest declares CAMERA, and once it is declared Android refuses to
/// hand back a picture unless the permission has actually been granted — the
/// capture just throws. Onboarding asks for it, but it can be skipped or
/// revoked later, so ask again here rather than failing at the shutter.
Future<bool> allowedCamera(BuildContext context) async {
  if (kIsWeb) return true;
  var status = await Permission.camera.status;
  if (status.isGranted) return true;
  if (status.isDenied) status = await Permission.camera.request();
  if (status.isGranted) return true;
  if (!context.mounted) return false;
  final go = await GFeedback.confirm(
    context,
    title: 'Camera is blocked'.tr,
    message:
        'Android will not open the camera until this app is allowed to use it. Turn it on in Settings and come back.'
            .tr,
    confirmLabel: 'Open settings'.tr,
  );
  if (go) await openAppSettings();
  return false;
}

/// Shoot or choose, and hand back what landed — paths already moved out of
/// the picker's cache, so Android is free to clear it. Empty when the pick
/// was cancelled or could not be opened.
Future<List<String>> capturePhotos(
  BuildContext context,
  ImageSource source,
) async {
  if (source == ImageSource.camera && !await allowedCamera(context)) {
    return const [];
  }
  try {
    final picker = ImagePicker();
    final files = source == ImageSource.camera
        ? [await picker.pickImage(source: source, imageQuality: 80)]
        : await picker.pickMultiImage(imageQuality: 80);
    return [for (final f in files.whereType<XFile>()) await keepImage(f.path)];
  } catch (_) {
    if (context.mounted) {
      GFeedback.error(
        context,
        source == ImageSource.camera
            ? 'Could not open the camera.'.tr
            : 'Could not open the gallery.'.tr,
      );
    }
    return const [];
  }
}

/// Ask where the picture comes from, then take it. The two answers are the
/// whole sheet — a camera that opens straight away would be wrong half the
/// time, since a card is just as often written off pictures already on the
/// phone as off the vehicle standing in front of the counter.
Future<List<String>> addPhotos(BuildContext context) async {
  final source = await GFeedback.sheet<ImageSource>(
    context,
    title: 'Add photos'.tr,
    subtitle: 'Shoot the vehicle, or pick what is already on the phone.'.tr,
    child: const _SourceOptions(),
  );
  if (source == null || !context.mounted) return const [];
  return capturePhotos(context, source);
}

/// One photograph, full bleed and zoomable. Both the card's photos panel and
/// the details step open this — a thumbnail that cannot be enlarged is no use
/// for settling what the scratch on it actually shows.
void previewPhoto(BuildContext context, String path) {
  showDialog<void>(
    context: context,
    barrierColor: context.c.scrim,
    builder: (context) {
      final p = context.c;
      return Dialog(
        insetPadding: const EdgeInsets.all(Gap.lg),
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: R.all(R.lg),
              child: InteractiveViewer(
                maxScale: 4,
                child: localImage(
                  path,
                  fit: BoxFit.contain,
                  fallback: () => Container(
                    height: 200,
                    color: p.surfaceSunken,
                    child: Center(
                      child: Text(
                        'Image unavailable'.tr,
                        style: AppType.bodyM.c(p.inkMuted),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: Gap.lg),
            GButton(
              label: 'Close'.tr,
              kind: GButtonKind.ghost,
              size: GButtonSize.md,
              expand: false,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    },
  );
}

class _SourceOptions extends StatelessWidget {
  const _SourceOptions();

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SourceRow(
              icon: Icons.photo_camera_rounded,
              tint: p.accent,
              label: 'Take a photo'.tr,
              subtitle: 'Open the camera now'.tr,
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            const SizedBox(height: Gap.sm),
            _SourceRow(
              icon: Icons.photo_library_rounded,
              tint: p.info,
              label: 'Choose from gallery'.tr,
              subtitle: 'Pick one or several'.tr,
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.icon,
    required this.tint,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color tint;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.lg,
          vertical: Gap.md,
        ),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: R.all(R.md),
          border: Border.all(color: p.line),
        ),
        child: Row(
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: p.isDark ? 0.18 : 0.10),
                borderRadius: R.all(R.sm),
              ),
              child: Icon(icon, size: 20, color: tint),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppType.labelL.c(p.ink)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppType.bodyS.c(p.inkMuted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: p.inkFaint),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/g_appbar.dart';
import '../../../core/widgets/g_button.dart';
import '../../../core/widgets/g_feedback.dart';
import '../../../core/widgets/g_art.dart';
import '../../../core/widgets/g_state.dart';
import '../../../core/widgets/local_image.dart';
import '../../../core/widgets/pressable.dart';
import '../../../state/admin_state.dart';
import '../../../state/providers.dart';
import '../widgets/photo_pick.dart';

/// Photographs taken at handover and during the work. The proof that settles
/// an argument about a scratch three weeks later.
class PhotosPage extends ConsumerStatefulWidget {
  const PhotosPage({super.key, required this.id});

  final String id;

  @override
  ConsumerState<PhotosPage> createState() => _PhotosPageState();
}

class _PhotosPageState extends ConsumerState<PhotosPage> {
  bool _busy = false;

  Future<void> _pick(ImageSource source) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final paths = await capturePhotos(context, source);
      if (paths.isNotEmpty) {
        ref.read(adminProvider.notifier).addPhotos(widget.id, paths);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final card = ref.watch(jobCardProvider(widget.id));
    if (card == null) {
      return Scaffold(
        appBar: GHeader(
          title: 'Photos'.tr,
          subtitle: 'The condition you took it in'.tr,
        ),
        body: GEmptyState(
          icon: Icons.photo_camera_outlined,
          title: 'Job card not found'.tr,
          art: Art.searching,
          message: 'Nothing to attach photos to.'.tr,
        ),
      );
    }

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Photos'.tr,
        subtitle: '{0} on this card'.trf([card.photos.length]),
      ),
      body: card.photos.isEmpty
          ? GEmptyState(
              icon: Icons.photo_camera_rounded,
              title: 'No photos yet'.tr,
              message:
                  'Shoot the vehicle at handover — panels, odometer, anything already damaged.'
                      .tr,
              actionLabel: 'Take a photo'.tr,
              onAction: () => _pick(ImageSource.camera),
            )
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(
                Gap.page,
                Gap.md,
                Gap.page,
                Gap.h2,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: Gap.sm,
                crossAxisSpacing: Gap.sm,
              ),
              itemCount: card.photos.length,
              itemBuilder: (context, i) {
                final path = card.photos[i];
                return Pressable(
                  onTap: () => previewPhoto(context, path),
                  scale: 0.96,
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: p.surfaceSunken,
                      borderRadius: R.all(R.md),
                      border: Border.all(color: p.line),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        localImage(
                          path,
                          fallback: () => Center(
                            child: Icon(
                              Icons.broken_image_rounded,
                              size: 22,
                              color: p.inkFaint,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Pressable(
                            onTap: () => ref
                                .read(adminProvider.notifier)
                                .removePhoto(widget.id, path),
                            scale: 0.85,
                            child: Container(
                              height: 24,
                              width: 24,
                              decoration: BoxDecoration(
                                color: p.scrim,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: GBottomBar(
        child: Row(
          children: [
            Expanded(
              child: GButton(
                label: 'Camera'.tr,
                kind: GButtonKind.outline,
                size: GButtonSize.lg,
                icon: Icons.photo_camera_rounded,
                expand: true,
                loading: _busy,
                onPressed: () => _pick(ImageSource.camera),
              ),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: GButton.accent(
                label: 'Gallery'.tr,
                icon: Icons.photo_library_rounded,
                onPressed: () => _pick(ImageSource.gallery),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

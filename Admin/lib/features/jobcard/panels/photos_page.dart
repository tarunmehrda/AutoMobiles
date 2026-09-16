import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/widgets/g_appbar.dart';
import '../../../core/widgets/g_button.dart';
import '../../../core/widgets/g_feedback.dart';
import '../../../core/widgets/g_state.dart';
import '../../../core/widgets/local_image.dart';
import '../../../core/widgets/pressable.dart';
import '../../../state/admin_state.dart';
import '../../../state/providers.dart';

/// Photographs taken at handover and during the work. The proof that settles
/// an argument about a scratch three weeks later.
class PhotosPage extends ConsumerStatefulWidget {
  const PhotosPage({super.key, required this.id});

  final String id;

  @override
  ConsumerState<PhotosPage> createState() => _PhotosPageState();
}

class _PhotosPageState extends ConsumerState<PhotosPage> {
  final _picker = ImagePicker();
  bool _busy = false;

  Future<void> _pick(ImageSource source) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final files = source == ImageSource.camera
          ? [await _picker.pickImage(source: source, imageQuality: 80)]
          : await _picker.pickMultiImage(imageQuality: 80);
      final paths =
          files.whereType<XFile>().map((f) => f.path).toList();
      if (paths.isNotEmpty) {
        ref.read(adminProvider.notifier).addPhotos(widget.id, paths);
      }
    } catch (e) {
      if (mounted) {
        GFeedback.error(context, 'Could not open the camera or gallery.');
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
      return const Scaffold(
        appBar: GHeader(title: 'Photos'),
        body: GEmptyState(
          icon: Icons.photo_camera_outlined,
          title: 'Job card not found',
          message: 'Nothing to attach photos to.',
        ),
      );
    }

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: GHeader(
        title: 'Photos',
        subtitle: '${card.photos.length} on this card',
      ),
      body: card.photos.isEmpty
          ? GEmptyState(
              icon: Icons.photo_camera_rounded,
              title: 'No photos yet',
              message: 'Shoot the vehicle at handover — panels, odometer, '
                  'anything already damaged.',
              actionLabel: 'Take a photo',
              onAction: () => _pick(ImageSource.camera),
            )
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(
                  Gap.page, Gap.md, Gap.page, Gap.h2),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: Gap.sm,
                crossAxisSpacing: Gap.sm,
              ),
              itemCount: card.photos.length,
              itemBuilder: (context, i) {
                final path = card.photos[i];
                return Pressable(
                  onTap: () => _preview(path),
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
                            child: Icon(Icons.broken_image_rounded,
                                size: 22, color: p.inkFaint),
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
                              child: const Icon(Icons.close_rounded,
                                  size: 14, color: Colors.white),
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
                label: 'Camera',
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
                label: 'Gallery',
                icon: Icons.photo_library_rounded,
                onPressed: () => _pick(ImageSource.gallery),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _preview(String path) {
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
                        child: Text('Image unavailable',
                            style: AppType.bodyM.c(p.inkMuted)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Gap.lg),
              GButton(
                label: 'Close',
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
}

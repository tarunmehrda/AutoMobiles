import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/widgets/local_image.dart';
import '../../../core/widgets/pressable.dart';

/// Picking a few photos of a part, and seeing what has been picked.
///
/// Photos are held as local file paths right up until the form is submitted,
/// and only then uploaded. A picture attached to a request the person then
/// abandons should not cost them their data or leave a file in the bucket
/// that nothing points at.
class PhotoStrip extends StatelessWidget {
  const PhotoStrip({
    super.key,
    required this.paths,
    required this.onChanged,
    this.max = 4,
    this.label = 'Photos',
    this.hint = 'A clear picture of the part helps us find the right one.',
  });

  final List<String> paths;
  final ValueChanged<List<String>> onChanged;
  final int max;
  final String label;
  final String hint;

  Future<void> _add(BuildContext context) async {
    final picker = ImagePicker();
    final room = max - paths.length;
    if (room <= 0) return;
    try {
      final picked = await picker.pickMultiImage(
        // Resized on the way in rather than on the way out. A modern phone
        // camera produces four-megabyte files, and nobody browsing parts on
        // a mobile connection benefits from one.
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 82,
        limit: room,
      );
      if (picked.isEmpty) return;
      onChanged([...paths, ...picked.take(room).map((x) => x.path)]);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the photo picker.')),
      );
    }
  }

  void _remove(int i) =>
      onChanged([...paths]..removeAt(i));

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: AppType.labelM.c(p.ink)),
            const SizedBox(width: Gap.sm),
            Text('Optional', style: AppType.labelS.c(p.inkFaint)),
          ],
        ),
        const SizedBox(height: Gap.xxs),
        Text(hint, style: AppType.bodyS.c(p.inkMuted)),
        const SizedBox(height: Gap.md),
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: paths.length + (paths.length < max ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(width: Gap.sm),
            itemBuilder: (context, i) {
              if (i == paths.length) {
                return Pressable(
                  onTap: () => _add(context),
                  scale: 0.96,
                  child: Container(
                    width: 84,
                    decoration: BoxDecoration(
                      color: p.surfaceSunken,
                      borderRadius: R.rMd,
                      border: Border.all(color: p.line),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined,
                            size: 20, color: p.inkMuted),
                        const SizedBox(height: Gap.xs),
                        Text('Add', style: AppType.labelS.c(p.inkMuted)),
                      ],
                    ),
                  ),
                );
              }
              return SizedBox(
                width: 84,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: R.rMd,
                        child: localImage(
                          paths[i],
                          fit: BoxFit.cover,
                          fallback: () => Container(
                            color: p.surfaceSunken,
                            child: Icon(Icons.broken_image_outlined,
                                size: 20, color: p.inkFaint),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: Pressable(
                        onTap: () => _remove(i),
                        scale: 0.9,
                        child: Container(
                          height: 22,
                          width: 22,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black54,
                          ),
                          child: const Icon(Icons.close_rounded,
                              size: 13, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

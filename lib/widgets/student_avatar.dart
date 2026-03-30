import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Circular avatar that shows the student photo (or initials fallback).
/// When [tappable] is true and a photo URL exists, tapping opens a
/// full-screen viewer dialog.
class StudentAvatar extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final double radius;
  final bool tappable;

  const StudentAvatar({
    super.key,
    required this.photoUrl,
    required this.name,
    this.radius = 24,
    this.tappable = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;

    final avatar = hasPhoto
        ? CircleAvatar(
            radius: radius,
            backgroundImage: CachedNetworkImageProvider(photoUrl!),
          )
        : CircleAvatar(
            radius: radius,
            backgroundColor:
                Theme.of(context).colorScheme.primaryContainer,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: radius * 0.8,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          );

    if (!tappable || !hasPhoto) return avatar;

    return GestureDetector(
      onTap: () => _showPhotoViewer(context),
      child: avatar,
    );
  }

  void _showPhotoViewer(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Blurred / dark background
            GestureDetector(
              onTap: () => Navigator.of(ctx).pop(),
              child: Container(color: Colors.black54),
            ),
            // Photo
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 400,
                maxHeight: 500,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: photoUrl!,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  errorWidget: (_, __, ___) => const Icon(
                    Icons.broken_image,
                    color: Colors.white,
                    size: 64,
                  ),
                ),
              ),
            ),
            // Close button
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

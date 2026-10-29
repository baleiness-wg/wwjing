import 'package:flutter/material.dart';

class BookmarkCover extends StatelessWidget {
  const BookmarkCover({
    super.key,
    required this.sourceUrl,
    this.sourceHost,
    this.coverUrl,
    this.width = 72,
    this.height = 72,
  });

  final String sourceUrl;
  final String? sourceHost;
  final String? coverUrl;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(sourceUrl.trim());
    final host = sourceHost?.trim().isNotEmpty == true
        ? sourceHost!.trim()
        : uri?.host.isNotEmpty == true
        ? uri!.host
        : '未知来源';
    final placeholder = Container(
      key: const Key('bookmark-cover-placeholder'),
      width: width,
      height: height,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        host,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
    final imageUri = Uri.tryParse(coverUrl?.trim() ?? '');
    if (imageUri == null ||
        !imageUri.hasAuthority ||
        (imageUri.scheme != 'http' && imageUri.scheme != 'https')) {
      return placeholder;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        imageUri.toString(),
        key: const Key('bookmark-cover-image'),
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      ),
    );
  }
}

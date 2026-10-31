import 'package:flutter/material.dart';

import '../models/bookmark.dart';
import 'bookmark_cover.dart';

class BookmarkItemCard extends StatelessWidget {
  const BookmarkItemCard({
    super.key,
    required this.item,
    required this.onTap,
    this.selectionValue,
    this.onSelectionChanged,
    this.onAction,
  });

  final BookmarkItem item;
  final VoidCallback onTap;
  final bool? selectionValue;
  final ValueChanged<bool?>? onSelectionChanged;
  final ValueChanged<String>? onAction;

  @override
  Widget build(BuildContext context) {
    final cover = BookmarkCover(
      sourceUrl: item.sourceUrl,
      sourceHost: item.sourceHost,
      coverUrl: item.coverUrl,
      width: 58,
      height: 58,
    );
    return Card(
      child: ListTile(
        leading: selectionValue == null
            ? cover
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: selectionValue,
                    onChanged: onSelectionChanged,
                  ),
                  cover,
                ],
              ),
        title: Text(
          item.title?.isNotEmpty == true ? item.title! : item.sourceUrl,
        ),
        subtitle: Text(
          item.sourceHost ?? item.sourceUrl,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: onTap,
        trailing: onAction == null
            ? null
            : PopupMenuButton<String>(
                tooltip: '更多操作',
                onSelected: onAction,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('编辑')),
                  PopupMenuItem(value: 'move', child: Text('移动')),
                  PopupMenuItem(value: 'delete', child: Text('删除')),
                ],
              ),
      ),
    );
  }
}

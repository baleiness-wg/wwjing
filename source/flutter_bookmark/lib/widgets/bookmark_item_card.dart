import 'package:flutter/material.dart';

import '../models/bookmark.dart';
import 'app_popup_menu.dart';
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
    return Card.outlined(
      color: Theme.of(context).colorScheme.surface,
      child: selectionValue != null
          ? CheckboxListTile(
              key: Key('bookmark-selection-${item.id}'),
              value: selectionValue,
              onChanged: onSelectionChanged,
              secondary: cover,
              title: Text(
                item.title?.isNotEmpty == true ? item.title! : item.sourceUrl,
              ),
              subtitle: Text(
                item.sourceHost ?? item.sourceUrl,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            )
          : ListTile(
              leading: cover,
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
                      icon: const Icon(Icons.more_vert),
                      onSelected: onAction,
                      itemBuilder: (_) => [
                        appPopupMenuItem(
                          value: 'edit',
                          icon: Icons.edit_outlined,
                          label: '编辑',
                        ),
                        appPopupMenuItem(
                          value: 'move',
                          icon: Icons.drive_file_move_outline,
                          label: '移动',
                        ),
                        appPopupMenuItem(
                          value: 'delete',
                          icon: Icons.delete_outline,
                          label: '删除',
                          destructive: true,
                        ),
                      ],
                    ),
            ),
    );
  }
}

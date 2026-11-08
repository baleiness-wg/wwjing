import 'package:flutter/material.dart';

import '../viewmodels/bookmark.dart';
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

  String _displayTitle(String value) {
    final runes = value.runes.toList();
    return runes.length <= 30
        ? value
        : '${String.fromCharCodes(runes.take(30))}...';
  }

  @override
  Widget build(BuildContext context) {
    final cover = BookmarkCover(
      sourceUrl: item.sourceUrl,
      sourceHost: item.sourceHost,
      coverUrl: item.coverUrl,
      width: 58,
      height: 58,
    );
    final title = Text(
      _displayTitle(item.title?.isNotEmpty == true ? item.title! : '未命名收藏'),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.w400,
      ),
    );
    final subtitle = Text(
      item.description?.isNotEmpty == true
          ? '${item.description!}${item.sourceUrl.isNotEmpty ? '\n${item.sourceUrl}' : ''}'
          : (item.sourceUrl.isNotEmpty ? item.sourceUrl : '暂无描述'),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall,
    );
    final action = onAction == null
        ? null
        : PopupMenuButton<String>(
            tooltip: '更多操作',
            icon: const Icon(Icons.more_vert),
            padding: EdgeInsets.zero,
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
          );
    if (selectionValue != null) {
      return Card.outlined(
        color: Theme.of(context).colorScheme.surface,
        margin: EdgeInsets.zero,
        child: CheckboxListTile(
          key: Key('bookmark-selection-${item.id}'),
          value: selectionValue,
          onChanged: onSelectionChanged,
          secondary: cover,
           contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          title: title,
          subtitle: subtitle,
        ),
      );
    }
    return Card.outlined(
      color: Theme.of(context).colorScheme.surface,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
           padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (selectionValue != null)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Checkbox(
                    key: Key('bookmark-selection-${item.id}'),
                    value: selectionValue,
                    onChanged: onSelectionChanged,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              cover,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [title, const SizedBox(height: 6), subtitle],
                ),
              ),
              if (action != null) ...[
                const SizedBox(width: 8),
                SizedBox(width: 44, child: action),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class BookmarkFolder {
  const BookmarkFolder({
    required this.id,
    required this.name,
    this.parentId,
    this.position = 0,
    this.pinned = false,
  });

  factory BookmarkFolder.fromJson(Map<String, dynamic> json) => BookmarkFolder(
    id: '${json['id']}',
    name: json['name'] as String? ?? '',
    parentId: json['parentId'] == null && json['parent_id'] == null
        ? null
        : '${json['parentId'] ?? json['parent_id']}',
    position: (json['position'] as num?)?.toInt() ?? 0,
    pinned: json['pinned'] == true,
  );

  final String id;
  final String name;
  final String? parentId;
  final int position;
  final bool pinned;
}

class FolderNode {
  FolderNode({required this.folder, required this.depth});

  final BookmarkFolder folder;
  final int depth;
  final List<FolderNode> children = [];
}

List<FolderNode> buildFolderTree(
  List<BookmarkFolder> folders, {
  int maxDepth = 8,
}) {
  final byId = {for (final folder in folders) folder.id: folder};
  final children = <String?, List<BookmarkFolder>>{};
  for (final folder in folders) {
    final parentId = folder.parentId;
    final validParent =
        parentId != null && parentId != folder.id && byId.containsKey(parentId);
    children.putIfAbsent(validParent ? parentId : null, () => []).add(folder);
  }
  for (final values in children.values) {
    values.sort((a, b) {
      final pin = (b.pinned ? 1 : 0).compareTo(a.pinned ? 1 : 0);
      if (pin != 0) return pin;
      final position = a.position.compareTo(b.position);
      return position != 0 ? position : a.name.compareTo(b.name);
    });
  }

  FolderNode? visit(BookmarkFolder folder, int depth, Set<String> path) {
    if (depth > maxDepth || path.contains(folder.id)) return null;
    final node = FolderNode(folder: folder, depth: depth);
    final nextPath = {...path, folder.id};
    for (final child in children[folder.id] ?? const <BookmarkFolder>[]) {
      final childNode = visit(child, depth + 1, nextPath);
      if (childNode != null) node.children.add(childNode);
    }
    return node;
  }

  return [
    for (final root in children[null] ?? const <BookmarkFolder>[])
      ?visit(root, 1, const {}),
  ];
}

Iterable<FolderNode> flattenFolderTree(List<FolderNode> roots) sync* {
  for (final root in roots) {
    yield root;
    yield* flattenFolderTree(root.children);
  }
}

class BookmarkItem {
  const BookmarkItem({
    required this.id,
    required this.sourceUrl,
    this.folderId,
    this.folderIds = const [],
    this.title,
    this.description,
    this.sourceHost,
    this.itemType = 'link',
    this.metadata = const {},
    this.pinned = false,
    this.images = const [],
  });

  factory BookmarkItem.fromJson(Map<String, dynamic> json) => BookmarkItem(
    id: '${json['id']}',
    sourceUrl:
        json['sourceUrl'] as String? ?? json['source_url'] as String? ?? '',
    folderId: json['folderId'] == null && json['folder_id'] == null
        ? null
        : '${json['folderId'] ?? json['folder_id']}',
    folderIds:
        (json['folderIds'] as List?)?.whereType<String>().toList() ?? const [],
    title: json['title'] as String?,
    description: json['description'] as String?,
    sourceHost: json['sourceHost'] as String? ?? json['source_host'] as String?,
    itemType:
        json['itemType'] as String? ?? json['item_type'] as String? ?? 'link',
    metadata: json['metadata'] is Map
        ? Map<String, dynamic>.from(json['metadata'] as Map)
        : const {},
    pinned: json['pinned'] == true,
    images:
        (json['images'] as List?)?.whereType<String>().toList() ??
        _legacyImages(json),
  );

  final String id;
  final String sourceUrl;
  final String? folderId;
  final List<String> folderIds;
  final String? title;
  final String? description;
  final String? sourceHost;
  final String itemType;
  final Map<String, dynamic> metadata;
  final bool pinned;
  final List<String> images;

  String? get coverUrl => images.isEmpty ? null : images.first;
}

List<String> _legacyImages(Map<String, dynamic> json) {
  final cover = json['coverUrl'] as String? ?? json['cover_url'] as String?;
  return cover == null ? const [] : [cover];
}

class BookmarkMetadata {
  const BookmarkMetadata({
    this.finalUrl,
    this.title,
    this.description,
    this.coverUrl,
  });

  factory BookmarkMetadata.fromJson(Map<String, dynamic> json) =>
      BookmarkMetadata(
        finalUrl: json['finalUrl'] as String?,
        title: json['title'] as String?,
        description: json['description'] as String?,
        coverUrl: json['coverUrl'] as String?,
      );

  final String? finalUrl;
  final String? title;
  final String? description;
  final String? coverUrl;
}

class BookmarkDraft {
  const BookmarkDraft({
    this.sourceUrl = '',
    this.title = '',
    this.description = '',
    this.folderId,
    this.folderIds = const [],
    this.images = const [],
    @Deprecated('Use images') this.coverUrl = '',
    this.fetchMetadataOnOpen = false,
  });

  final String sourceUrl;
  final String title;
  final String description;
  final String? folderId;
  final List<String> folderIds;
  final List<String> images;
  final String coverUrl;
  final bool fetchMetadataOnOpen;
}

class InspirationEntry {
  const InspirationEntry({
    required this.id,
    required this.content,
    this.title,
    this.folderId,
    this.createdAt,
    this.updatedAt,
    this.completed = false,
  });

  factory InspirationEntry.fromBookmarkItem(BookmarkItem item) =>
      InspirationEntry(
        id: item.id,
        title: item.title,
        content: item.description ?? '',
        folderId: item.folderId,
        completed: item.metadata['completed'] == true,
      );

  factory InspirationEntry.fromJson(Map<String, dynamic> json) =>
      InspirationEntry(
        id: '${json['id']}',
        title: json['title'] as String?,
        content: json['content'] as String? ?? '',
        folderId: json['folderId'] == null && json['folder_id'] == null
            ? null
            : '${json['folderId'] ?? json['folder_id']}',
        createdAt: json['createdAt'] as String?,
        updatedAt: json['updatedAt'] as String?,
      );

  final String id;
  final String? title;
  final String content;
  final String? folderId;
  final String? createdAt;
  final String? updatedAt;
  final bool completed;
}

class DuplicateBookmarkInfo {
  const DuplicateBookmarkInfo({
    required this.id,
    this.folderId,
    this.folderName,
    this.title,
  });

  factory DuplicateBookmarkInfo.fromJson(Object? value) {
    final json = value is Map<String, dynamic>
        ? value
        : const <String, dynamic>{};
    return DuplicateBookmarkInfo(
      id: '${json['id'] ?? ''}',
      folderId: json['folderId'] == null && json['folder_id'] == null
          ? null
          : '${json['folderId'] ?? json['folder_id']}',
      folderName:
          json['folderName'] as String? ?? json['folder_name'] as String?,
      title: json['title'] as String?,
    );
  }

  final String id;
  final String? folderId;
  final String? folderName;
  final String? title;
}

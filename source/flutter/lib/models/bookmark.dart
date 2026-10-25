class BookmarkFolder {
  const BookmarkFolder({
    required this.id,
    required this.name,
    this.parentId,
    this.position = 0,
  });

  factory BookmarkFolder.fromJson(Map<String, dynamic> json) => BookmarkFolder(
    id: '${json['id']}',
    name: json['name'] as String? ?? '',
    parentId: json['parentId'] == null && json['parent_id'] == null
        ? null
        : '${json['parentId'] ?? json['parent_id']}',
    position: (json['position'] as num?)?.toInt() ?? 0,
  );

  final String id;
  final String name;
  final String? parentId;
  final int position;
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
    this.title,
    this.description,
    this.sourceHost,
  });

  factory BookmarkItem.fromJson(Map<String, dynamic> json) => BookmarkItem(
    id: '${json['id']}',
    sourceUrl:
        json['sourceUrl'] as String? ?? json['source_url'] as String? ?? '',
    folderId: json['folderId'] == null && json['folder_id'] == null
        ? null
        : '${json['folderId'] ?? json['folder_id']}',
    title: json['title'] as String?,
    description: json['description'] as String?,
    sourceHost: json['sourceHost'] as String? ?? json['source_host'] as String?,
  );

  final String id;
  final String sourceUrl;
  final String? folderId;
  final String? title;
  final String? description;
  final String? sourceHost;
}

class BookmarkDraft {
  const BookmarkDraft({
    required this.sourceUrl,
    this.title = '',
    this.description = '',
    this.folderId,
  });

  final String sourceUrl;
  final String title;
  final String description;
  final String? folderId;
}

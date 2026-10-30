import 'package:flutter_test/flutter_test.dart';
import 'package:wwjing_bookmark/models/bookmark.dart';

void main() {
  test('构建多根、多层目录并将异常父标识提升到根', () {
    final tree = buildFolderTree(const [
      BookmarkFolder(id: '2', name: '子目录', parentId: '1'),
      BookmarkFolder(id: '1', name: '根目录'),
      BookmarkFolder(id: '3', name: '异常目录', parentId: 'missing'),
    ]);
    expect(tree, hasLength(2));
    expect(tree.first.folder.id, '3');
    expect(tree.last.children.single.folder.id, '2');
  });

  test('空列表和最多八层', () {
    expect(buildFolderTree(const []), isEmpty);
    final folders = List.generate(
      9,
      (index) => BookmarkFolder(
        id: '$index',
        name: '$index',
        parentId: index == 0 ? null : '${index - 1}',
      ),
    );
    expect(flattenFolderTree(buildFolderTree(folders)).length, 8);
  });
}

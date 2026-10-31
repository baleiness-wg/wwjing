import 'package:flutter/material.dart';

import '../models/bookmark.dart';
import '../state/app_state.dart';

Future<String?> showFolderPicker({
  required BuildContext context,
  required AppState state,
  required String title,
  String? selectedFolderId,
  String rootLabel = '未分类',
  Set<String> excludedFolderIds = const {},
  bool allowCreate = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => FolderPickerDialog(
      state: state,
      title: title,
      selectedFolderId: selectedFolderId,
      rootLabel: rootLabel,
      excludedFolderIds: excludedFolderIds,
      allowCreate: allowCreate,
    ),
  );
}

Future<String?> showFolderNameDialog(
  BuildContext context, {
  String title = '新增目录',
  String initial = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _FolderNameDialog(title: title, initial: initial),
  );
}

class _FolderNameDialog extends StatefulWidget {
  const _FolderNameDialog({required this.title, required this.initial});

  final String title;
  final String initial;

  @override
  State<_FolderNameDialog> createState() => _FolderNameDialogState();
}

class _FolderNameDialogState extends State<_FolderNameDialog> {
  late final controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const Key('folder-name-field'),
        controller: controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          labelText: '目录名称',
          prefixIcon: Icon(Icons.create_new_folder_outlined),
        ),
        onSubmitted: (value) => Navigator.pop(context, value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('确定'),
        ),
      ],
    );
  }
}

class FolderPickerDialog extends StatefulWidget {
  const FolderPickerDialog({
    super.key,
    required this.state,
    required this.title,
    this.selectedFolderId,
    this.rootLabel = '未分类',
    this.excludedFolderIds = const {},
    this.allowCreate = false,
  });

  final AppState state;
  final String title;
  final String? selectedFolderId;
  final String rootLabel;
  final Set<String> excludedFolderIds;
  final bool allowCreate;

  @override
  State<FolderPickerDialog> createState() => _FolderPickerDialogState();
}

class _FolderPickerDialogState extends State<FolderPickerDialog> {
  late String selectedFolderId = widget.selectedFolderId ?? '';
  final newFolderController = TextEditingController();
  final newFolderFocusNode = FocusNode();
  bool creatingFolder = false;

  void _createFolder() {
    setState(() {
      creatingFolder = true;
      newFolderController.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) newFolderFocusNode.requestFocus();
    });
  }

  Future<void> _confirmCreateFolder() async {
    final name = newFolderController.text.trim();
    if (name.isEmpty || widget.state.busy) return;
    final parentId = selectedFolderId.isEmpty ? null : selectedFolderId;
    final folder = await widget.state.createFolder(name, parentId);
    if (!mounted || folder == null) return;
    setState(() {
      selectedFolderId = folder.id;
      creatingFolder = false;
      newFolderController.clear();
    });
  }

  void _cancelCreateFolder() {
    setState(() {
      creatingFolder = false;
      newFolderController.clear();
    });
  }

  Widget _inlineFolderEditor(int depth) {
    return Padding(
      key: const Key('inline-folder-editor'),
      padding: EdgeInsets.only(left: depth * 16.0),
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(vertical: -4),
        minTileHeight: 44,
        contentPadding: const EdgeInsets.only(left: 12, right: 4),
        leading: const Icon(Icons.create_new_folder_outlined, size: 20),
        title: TextField(
          key: const Key('inline-folder-name-field'),
          controller: newFolderController,
          focusNode: newFolderFocusNode,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            isDense: true,
            hintText: '输入目录名称',
            border: InputBorder.none,
          ),
          onSubmitted: (_) => _confirmCreateFolder(),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: const Key('cancel-inline-folder-button'),
              tooltip: '取消新增',
              onPressed: _cancelCreateFolder,
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close),
            ),
            IconButton(
              key: const Key('confirm-inline-folder-button'),
              tooltip: '创建目录',
              onPressed: widget.state.busy ? null : _confirmCreateFolder,
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              visualDensity: VisualDensity.compact,
              color: Colors.green,
              disabledColor: Theme.of(context).colorScheme.onSurfaceVariant,
              icon: const Icon(Icons.check),
            ),
          ],
        ),
      ),
    );
  }

  Widget _folderTile({
    required Key key,
    required String value,
    required String label,
    required IconData icon,
  }) {
    final selected = selectedFolderId == value;
    return ListTile(
      key: key,
      dense: true,
      selected: selected,
      selectedColor: Theme.of(context).colorScheme.primary,
      selectedTileColor: Theme.of(context).colorScheme.primary
          .withValues(alpha: 0.08),
      visualDensity: const VisualDensity(vertical: -4),
      minTileHeight: 40,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      leading: Icon(icon, size: 20),
      title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () {
        setState(() {
          selectedFolderId = value;
          creatingFolder = false;
          newFolderController.clear();
        });
      },
    );
  }

  @override
  void dispose() {
    newFolderController.dispose();
    newFolderFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nodes = flattenFolderTree(widget.state.folderTree)
        .where((node) => !widget.excludedFolderIds.contains(node.folder.id))
        .toList();
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(widget.title)),
          if (widget.allowCreate)
            IconButton(
              key: const Key('create-folder-button'),
              tooltip: selectedFolderId.isEmpty ? '新增根目录' : '新增子目录',
              onPressed: _createFolder,
              icon: const Icon(Icons.create_new_folder_outlined),
            ),
        ],
      ),
      content: SizedBox(
        width: 440,
        height: MediaQuery.sizeOf(context).height * .6,
        child: Card.outlined(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 2),
            children: [
              _folderTile(
                key: const Key('folder-option-root'),
                value: '',
                label: widget.rootLabel,
                icon: Icons.folder_off_outlined,
              ),
              if (creatingFolder && selectedFolderId.isEmpty)
                _inlineFolderEditor(1),
              for (final node in nodes) ...[
                Padding(
                  padding: EdgeInsets.only(left: (node.depth - 1) * 16.0),
                  child: _folderTile(
                    key: Key('folder-option-${node.folder.id}'),
                    value: node.folder.id,
                    label: node.folder.name,
                    icon: Icons.folder_outlined,
                  ),
                ),
                if (creatingFolder && selectedFolderId == node.folder.id)
                  _inlineFolderEditor(node.depth),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, selectedFolderId),
          child: const Text('选择'),
        ),
      ],
    );
  }
}

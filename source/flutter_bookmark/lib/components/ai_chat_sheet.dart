import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import '../api/api_client.dart';
import '../utils/link_launcher.dart';

class AiChatSheet extends StatefulWidget {
  const AiChatSheet({
    super.key,
    required this.api,
    required this.directoryContext,
    this.linkLauncher = const LinkLauncher(),
  });

  final ApiClient api;
  final Map<String, Object?> directoryContext;
  final LinkLauncher linkLauncher;

  @override
  State<AiChatSheet> createState() => _AiChatSheetState();
}

class _ChatMessage {
  const _ChatMessage(this.role, this.content);
  final String role;
  final String content;
}

class _AiChatSheetState extends State<AiChatSheet> {
  static final Map<String, List<_ChatMessage>> _savedSessions = {};
  final _input = TextEditingController();
  final _scrollController = ScrollController();
  late final List<_ChatMessage> _messages;
  bool _sending = false;
  String? _failedMessage;

  String get _sessionKey =>
      '${widget.directoryContext['space']}:${widget.directoryContext['directoryId'] ?? 'all'}';

  @override
  void initState() {
    super.initState();
    _messages = _savedSessions.putIfAbsent(_sessionKey, () => <_ChatMessage>[]);
  }

  @override
  void dispose() {
    _input.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send([String? value]) async {
    final message = (value ?? _input.text).trim();
    if (message.isEmpty || _sending) return;
    _input.clear();
    setState(() {
      _failedMessage = null;
      _messages.add(_ChatMessage('user', message));
      _messages.add(const _ChatMessage('thinking', 'AI 正在思考，请稍候...'));
      _sending = true;
    });
    _scrollToEnd();
    try {
      final history = _messages
          .take(_messages.length - 1)
          .where((entry) => entry.role == 'user' || entry.role == 'assistant')
          .map((entry) => {'role': entry.role, 'content': entry.content})
          .toList();
      final result = await widget.api.chatWithDirectory(
        context: widget.directoryContext,
        message: message,
        history: history,
      );
      _messages.removeWhere((entry) => entry.role == 'thinking');
      _messages.add(_ChatMessage('assistant', result.answer));
      if (mounted) setState(() => _sending = false);
    } on ApiException catch (error) {
      _messages.removeWhere((entry) => entry.role == 'thinking');
      _messages.add(_ChatMessage('error', error.message));
      if (mounted) {
        setState(() {
          _failedMessage = message;
          _input.text = message;
          _sending = false;
        });
      }
    } catch (_) {
      _messages.removeWhere((entry) => entry.role == 'thinking');
      _messages.add(const _ChatMessage('error', 'AI 请求失败，请稍后重试。'));
      if (mounted) {
        setState(() {
          _failedMessage = message;
          _input.text = message;
          _sending = false;
        });
      }
    }
    _scrollToEnd();
  }

  void _retry() {
    final message = _failedMessage;
    if (message == null) return;
    final index = _messages.lastIndexWhere((entry) => entry.role == 'error');
    if (index >= 0) _messages.removeAt(index);
    final userIndex = _messages.lastIndexWhere(
      (entry) => entry.role == 'user' && entry.content == message,
    );
    if (userIndex >= 0) _messages.removeAt(userIndex);
    _failedMessage = null;
    _send(message);
  }

  void _scrollToEnd() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final directory =
        widget.directoryContext['directoryPath'] as String? ?? '全部收藏';
    final count = widget.directoryContext['loadedItemCount'] as int? ?? 0;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .78,
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  Icons.auto_awesome,
                  color: theme.colorScheme.primary,
                ),
                title: const Text('AI Chat'),
                subtitle: Text(
                  directory,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  tooltip: '关闭 AI Chat',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Text(
                            '我可以根据当前已加载的 $count 条收藏和你讨论。\n不会自动读取网页全文。',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          return _MessageBubble(
                            role: message.role,
                            content: message.content,
                            onOpenLink: (url) =>
                                widget.linkLauncher.open(context, url),
                          );
                        },
                      ),
              ),
              if (_failedMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('请求未完成'),
                      TextButton.icon(
                        onPressed: _retry,
                        icon: const Icon(Icons.refresh),
                        label: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 4000,
                        enabled: !_sending,
                        decoration: const InputDecoration(
                          hintText: '输入你想讨论的问题',
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: '发送',
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.role,
    required this.content,
    this.onOpenLink,
  });
  final String role;
  final String content;
  final Future<bool> Function(String url)? onOpenLink;

  @override
  Widget build(BuildContext context) {
    final isUser = role == 'user';
    final isError = role == 'error';
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: isError
              ? colorScheme.errorContainer
              : isUser
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: _LinkText(
          content: content,
          color: isUser ? colorScheme.onPrimary : null,
          onOpenLink: onOpenLink,
        ),
      ),
    );
  }
}

class _LinkText extends StatelessWidget {
  const _LinkText({required this.content, this.color, this.onOpenLink});
  final String content;
  final Color? color;
  final Future<bool> Function(String url)? onOpenLink;

  @override
  Widget build(BuildContext context) {
    final parts = content.split(RegExp(r'(https?://[^\s<>()]+)'));
    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: color ?? Theme.of(context).colorScheme.onSurface,
        ),
        children: [
          for (final part in parts)
            if (RegExp(r'^https?://').hasMatch(part))
              TextSpan(
                text: part,
                style: const TextStyle(
                  decoration: TextDecoration.underline,
                  color: Colors.teal,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () => onOpenLink?.call(part),
              )
            else
              TextSpan(text: part),
        ],
      ),
    );
  }
}

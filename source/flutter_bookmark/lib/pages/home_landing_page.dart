import 'package:flutter/material.dart';

import '../constants/app_config.dart';

import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../components/ai_chat_sheet.dart';
import '../stores/bookmark_state.dart';
import '../utils/link_launcher.dart';

class HomeLandingPage extends StatefulWidget {
  const HomeLandingPage({super.key, required this.appConfig});

  final AppConfig appConfig;

  @override
  State<HomeLandingPage> createState() => _HomeLandingPageState();
}

class _HomeLandingPageState extends State<HomeLandingPage> {
  List<String> _recommendations = [];
  bool _busy = false;
  final _linkLauncher = const LinkLauncher();

  @override
  void initState() {
    super.initState();
    _initializeHome();
  }

  Future<void> _initializeHome() async {
    final state = context.read<AppState>();
    while (state.busy) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    final saved = await state.preferences.recommendations();
    if (!mounted) return;
    setState(() => _recommendations = saved);
    if (saved.isEmpty) await _refreshRecommendation();
  }

  Future<void> _refreshRecommendation() async {
    if (_busy) return;
    setState(() => _busy = true);
    final state = context.read<AppState>();
    try {
      final result = await state.api.chatWithDirectory(
        context: {
          'space': widget.appConfig.space,
          'directoryName': '全部收藏',
          'directoryPath': '全部收藏',
          'loadedItemCount': state.items.length,
          'items': [
            for (final item in state.items)
              {
                'title': item.title,
                'description': item.description,
                'sourceUrl': item.sourceUrl,
              },
          ],
        },
        message: '请根据我的收藏，推荐一个现在可以做的具体事情。只给出简短、可执行的建议。',
      );
      await state.preferences.saveRecommendation(result.answer);
      final saved = await state.preferences.recommendations();
      if (mounted) setState(() => _recommendations = saved);
    } on ApiException catch (error) {
      if (mounted && _recommendations.isEmpty) {
        setState(() => _recommendations = [error.message]);
      }
    } catch (_) {
      if (mounted && _recommendations.isEmpty) {
        setState(() => _recommendations = ['暂时无法获取推荐，请稍后重试']);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            tooltip: '刷新推荐',
            onPressed: _busy ? null : _refreshRecommendation,
            icon: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _recommendations.isEmpty
          ? const Center(child: Text('正在准备今日推荐...'))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: _recommendations.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: MarkdownMessage(
                    content: _recommendations[index],
                    onOpenLink: (url) => _linkLauncher.open(context, url),
                  ),
                ),
              ),
            ),
    );
  }
}

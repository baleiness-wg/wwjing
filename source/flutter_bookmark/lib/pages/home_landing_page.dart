import 'package:flutter/material.dart';

import '../constants/app_config.dart';

import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../components/bookmark_item_card.dart';
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
  List<String> _recommendationItemIds = [];
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
    final savedIds = await state.preferences.recommendationItemIds();
    if (!mounted) return;
    setState(() {
      _recommendations = saved;
      _recommendationItemIds = savedIds;
    });
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
                'id': item.id,
                'title': item.title,
                'description': item.description,
                'sourceUrl': item.sourceUrl,
              },
          ],
        },
        message: '请严格使用中文回答。请从当前收藏中选择一个最适合现在执行的收藏，只返回该收藏的 id 和一句简短理由，格式为：id: <收藏id>\n理由: <中文理由>。禁止编造 id 或链接。',
      );
      await state.preferences.saveRecommendation(result.answer);
      final match = RegExp(
        r'id\s*[:：]\s*([a-f0-9]{32})',
        caseSensitive: false,
      ).firstMatch(result.answer);
      if (match != null) {
        await state.preferences.saveRecommendationItemId(match.group(1)!);
      }
      final saved = await state.preferences.recommendations();
      final savedIds = await state.preferences.recommendationItemIds();
      if (mounted) {
        setState(() {
          _recommendations = saved;
          _recommendationItemIds = savedIds;
        });
      }
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
        title: const Text('Recommend'),
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
      body: _recommendationItemIds.isEmpty
          ? const Center(child: Text('正在准备今日推荐...'))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: _recommendationItemIds.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = context
                    .read<AppState>()
                    .items
                    .where((item) => item.id == _recommendationItemIds[index])
                    .firstOrNull;
                if (item == null) return const SizedBox.shrink();
                return BookmarkItemCard(
                  item: item,
                  onTap: () => _linkLauncher.open(context, item.sourceUrl),
                  onAction: (action) {
                    if (action == 'edit') {
                      context.read<AppState>().openDraft(item);
                    }
                  },
                );
              },
            ),
    );
  }
}

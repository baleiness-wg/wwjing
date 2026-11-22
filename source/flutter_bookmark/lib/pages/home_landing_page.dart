import 'package:flutter/material.dart';

import 'dart:math';

import '../constants/app_config.dart';

import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../components/bookmark_item_card.dart';
import '../components/ai_chat_sheet.dart';
import '../stores/bookmark_state.dart';
import '../utils/link_launcher.dart';
import '../viewmodels/bookmark.dart';

class HomeLandingPage extends StatefulWidget {
  const HomeLandingPage({super.key, required this.appConfig});

  final AppConfig appConfig;

  @override
  State<HomeLandingPage> createState() => _HomeLandingPageState();
}

class _HomeLandingPageState extends State<HomeLandingPage> {
  List<String> _recommendations = [];
  List<String> _recommendationItemIds = [];
  List<BookmarkItem> _allItems = [];
  bool _busy = false;
  String _status = '正在准备今日推荐...';
  final _linkLauncher = const LinkLauncher();

  @override
  void initState() {
    super.initState();
    _initializeHome();
  }

  Future<void> _initializeHome() async {
    final state = context.read<AppState>();
    while (!state.initialized || state.busy) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    final allItems = await state.api.getAllItems();
    final savedRaw = (await state.preferences.recommendations())
        .take(10)
        .toList();
    final savedIdsRaw = (await state.preferences.recommendationItemIds())
        .take(10)
        .toList();
    final pairCount = savedRaw.length < savedIdsRaw.length
        ? savedRaw.length
        : savedIdsRaw.length;
    final saved = savedRaw.take(pairCount).toList();
    final savedIds = savedIdsRaw.take(pairCount).toList();
    if (!mounted) return;
    final availableIds = allItems.map((item) => item.id).toSet();
    final validSavedIds = savedIds.where(availableIds.contains).toList();
    setState(() {
      _recommendations = saved;
      _recommendationItemIds = validSavedIds;
      _allItems = allItems;
      if (allItems.isEmpty) _status = '还没有收藏，先去 Star 添加一些内容吧';
    });
    if (validSavedIds.isEmpty && state.items.isNotEmpty) {
      await _refreshRecommendation();
    }
  }

  Future<void> _refreshRecommendation() async {
    if (_busy) return;
    setState(() => _busy = true);
    final state = context.read<AppState>();
    List<BookmarkItem> allItems = const [];
    try {
      allItems = await state.api.getAllItems();
      if (mounted) setState(() => _allItems = allItems);
      final recentIds = await state.preferences.recommendationItemIds();
      final now = DateTime.now();
      const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      final period = now.hour < 6
          ? '深夜'
          : now.hour < 9
          ? '早晨'
          : now.hour < 12
          ? '上午'
          : now.hour < 14
          ? '午间'
          : now.hour < 18
          ? '下午'
          : now.hour < 22
          ? '晚上'
          : '夜间';
      final candidates = [...allItems]..shuffle(Random());
      final preferredCandidates = <BookmarkItem>[
        ...candidates.where((item) => !recentIds.take(5).contains(item.id)),
        ...candidates.where((item) => recentIds.take(5).contains(item.id)),
      ];
      if (preferredCandidates.isEmpty) {
        if (mounted) setState(() => _status = '还没有可推荐的收藏');
        return;
      }
      final selectedItem = preferredCandidates.first;
      final result = await state.api.chatWithDirectory(
        context: {
          'space': widget.appConfig.space,
          'directoryName': '全部收藏',
          'directoryPath': '全部收藏',
          'loadedItemCount': allItems.length,
          'items': [
            {
              'id': selectedItem.id,
              'title': selectedItem.title,
              'description': selectedItem.description,
              'sourceUrl': selectedItem.sourceUrl,
            },
          ],
        },
        message:
            '''请严格使用简体中文回答。现在是 ${now.year}年${now.month}月${now.day}日 ${weekdays[now.weekday - 1]} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}，属于$period。
请只围绕指定收藏，像熟悉用户的朋友一样推荐现在可以做的具体事情。不要机械重复完整日期，不要输出链接或 Markdown 语法，只返回一到三句自然中文推荐语。
指定收藏：${selectedItem.title ?? '未命名收藏'}
理由应说明为什么现在适合做这件事。''',
      );
      await state.preferences.saveRecommendation(result.answer);
      await state.preferences.saveRecommendationItemId(selectedItem.id);
      final savedRaw = (await state.preferences.recommendations())
          .take(10)
          .toList();
      final savedIdsRaw = (await state.preferences.recommendationItemIds())
          .take(10)
          .toList();
      final pairCount = savedRaw.length < savedIdsRaw.length
          ? savedRaw.length
          : savedIdsRaw.length;
      final saved = savedRaw.take(pairCount).toList();
      final savedIds = savedIdsRaw.take(pairCount).toList();
      if (mounted) {
        setState(() {
          _recommendations = saved;
          _recommendationItemIds = savedIds;
          _status = savedIds.isEmpty ? '暂时没有可推荐的收藏' : '';
        });
      }
    } on ApiException catch (error) {
      if (allItems.isNotEmpty) {
        await state.preferences.saveRecommendationItemId(allItems.first.id);
        if (mounted) {
          setState(
            () => _recommendationItemIds = [
              allItems.first.id,
              ..._recommendationItemIds,
            ].take(10).toList(),
          );
        }
      }
      if (mounted && _recommendations.isEmpty) {
        setState(() => _status = '推荐失败：${error.message}');
      }
    } catch (_) {
      if (allItems.isNotEmpty) {
        await state.preferences.saveRecommendationItemId(allItems.first.id);
        if (mounted) {
          setState(
            () => _recommendationItemIds = [
              allItems.first.id,
              ..._recommendationItemIds,
            ].take(10).toList(),
          );
        }
      }
      if (mounted && _recommendations.isEmpty) {
        setState(() => _status = '推荐失败，请稍后重试');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _recommendationText(int index) {
    if (index >= _recommendations.length) return '根据你的收藏推荐这条内容。';
    final text = _recommendations[index]
        .replaceAllMapped(
          RegExp(r'\[([^\]]+)\]\(https?://[^)\s]+\)'),
          (match) => match.group(1)!,
        )
        .replaceFirst(RegExp(r'^\s*id\s*[:：].*$', multiLine: true), '')
        .replaceFirst(RegExp(r'^\s*理由\s*[:：]\s*', multiLine: true), '')
        .trim();
    return text.isEmpty ? '根据你的收藏推荐这条内容。' : text;
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
          ? Center(child: Text(_status))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: _recommendationItemIds.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = _allItems
                    .where((item) => item.id == _recommendationItemIds[index])
                    .firstOrNull;
                if (item == null) return const SizedBox.shrink();
                return Card(
                  clipBehavior: Clip.antiAlias,
                  elevation: 2,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.primary
                          .withValues(alpha: 0.28),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        child: MarkdownMessage(
                          content: _recommendationText(index),
                        ),
                      ),
                      const Divider(height: 1),
                      BookmarkItemCard(
                        item: item,
                        compact: true,
                        embedded: true,
                        onTap: () =>
                            _linkLauncher.open(context, item.sourceUrl),
                        onAction: (action) {
                          if (action == 'edit') {
                            context.read<AppState>().openDraft(item);
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

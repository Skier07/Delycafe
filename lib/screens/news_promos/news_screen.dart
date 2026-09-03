import 'package:cached_network_image/cached_network_image.dart';
import 'package:delycafe/config/api_config.dart';
import 'package:delycafe/models/content_post.dart';
import 'package:delycafe/screens/news_promos/news_detail_screen.dart';
import 'package:delycafe/services/content_api_service.dart';
import 'package:delycafe/ui/tokens/app_colors.dart';
import 'package:flutter/material.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final ContentApiService _api = ContentApiService();
  late Future<List<ContentPost>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.fetchPosts(type: 'news');
  }

  Future<void> _reload() async {
    setState(() {
      _future = _api.fetchPosts(type: 'news');
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ContentPost>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.header),
          );
        }

        if (snapshot.hasError) {
          return _ErrorState(
            message: 'Не удалось загрузить новости',
            onRetry: _reload,
          );
        }

        final posts = snapshot.data ?? const [];

        if (posts.isEmpty) {
          return const Center(
            child: Text(
              'Новостей пока нет',
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: posts.length,
            itemBuilder: (context, i) {
              final item = posts[i];
              final cover = ApiConfig.normalizeMediaUrl(item.coverImage);

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NewsDetailScreen(post: item),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: AppColors.header.withValues(alpha: 0.12),
                    image: cover.isEmpty
                        ? null
                        : DecorationImage(
                            image: CachedNetworkImageProvider(cover),
                            fit: BoxFit.cover,
                          ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.6),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    alignment: Alignment.bottomLeft,
                    child: Text(
                      item.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}

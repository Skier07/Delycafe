import 'package:cached_network_image/cached_network_image.dart';
import 'package:delycafe/config/api_config.dart';
import 'package:delycafe/models/content_post.dart';
import 'package:delycafe/screens/news_promos/news_detail_screen.dart';
import 'package:delycafe/services/content_api_service.dart';
import 'package:delycafe/ui/tokens/app_colors.dart';
import 'package:flutter/material.dart';

class PromoScreen extends StatefulWidget {
  const PromoScreen({super.key});

  @override
  State<PromoScreen> createState() => _PromoScreenState();
}

class _PromoScreenState extends State<PromoScreen> {
  final ContentApiService _api = ContentApiService();
  late Future<List<ContentPost>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.fetchPosts(type: 'promo');
  }

  Future<void> _reload() async {
    setState(() {
      _future = _api.fetchPosts(type: 'promo');
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
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Не удалось загрузить акции'),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _reload,
                  child: const Text('Повторить'),
                ),
              ],
            ),
          );
        }

        final posts = snapshot.data ?? const [];

        if (posts.isEmpty) {
          return const Center(
            child: Text(
              'Акций пока нет\nНо мы уже готовим для вас что-то вкусное',
              textAlign: TextAlign.center,
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

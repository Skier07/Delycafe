import 'package:cached_network_image/cached_network_image.dart';
import 'package:delycafe/config/api_config.dart';
import 'package:delycafe/models/content_post.dart';
import 'package:delycafe/ui/components/glass/shader_glass_container.dart';
import 'package:delycafe/widgets/content/content_blocks_renderer.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class NewsDetailScreen extends StatelessWidget {
  final ContentPost post;

  const NewsDetailScreen({
    super.key,
    required this.post,
  });

  @override
  Widget build(BuildContext context) {
    final cover = ApiConfig.normalizeMediaUrl(post.coverImage);

    return Scaffold(
      backgroundColor: const Color(0xFFFEF7FF),
      body: Column(
        children: [
          Stack(
            children: [
              if (cover.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: cover,
                  height: 260,
                  width: double.infinity,
                  fit: BoxFit.cover,
                )
              else
                Container(
                  height: 180,
                  width: double.infinity,
                  color: const Color(0xFF0C204D),
                ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: ShaderGlassContainer(
                    borderRadius: 30,
                    onPressed: () => Navigator.pop(context),
                    padding: const EdgeInsets.all(8),
                    child: const Icon(
                      CupertinoIcons.chevron_left_2,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ContentBlocksRenderer(lines: post.bodyLines),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:delycafe/ui/components/glass/shader_glass_container.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class NewsDetailScreen extends StatelessWidget {
  final String title;
  final String text;
  final String image;

  const NewsDetailScreen({
    super.key,
    required this.title,
    required this.text,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEF7FF),
      body: Column(
        children: [
          Stack(
            children: [
              Image.asset(
                image,
                height: 260,
                width: double.infinity,
                fit: BoxFit.cover,
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
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

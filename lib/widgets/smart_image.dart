

import 'dart:convert';
import 'package:flutter/material.dart';

class SmartImage extends StatelessWidget {
  const SmartImage(
      this.source, {
        super.key,
        this.fit = BoxFit.cover,
        this.height,
        this.width,
      });

  final String  source;
  final BoxFit  fit;
  final double? height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    // New format: base64 data URI stored directly in Firestore
    if (source.startsWith('data:image')) {
      try {
        final base64Str = source.split(',').last;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          fit: fit,
          height: height,
          width: width,
          errorBuilder: (_, __, ___) => _errorBox(),
        );
      } catch (_) {
        return _errorBox();
      }
    }

    // Backward compatibility: old Firebase Storage https URLs
    return Image.network(
      source,
      fit: fit,
      height: height,
      width: width,
      loadingBuilder: (ctx, child, progress) {
        if (progress == null) return child;
        return const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
      errorBuilder: (_, __, ___) => _errorBox(),
    );
  }

  Widget _errorBox() => Container(
    color: Colors.grey[200],
    height: height,
    width: width,
    child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
  );
}
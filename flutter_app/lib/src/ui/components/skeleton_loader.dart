import 'package:flutter/material.dart';

/// A shimmering placeholder box shown in place of list rows while data loads.
class SkeletonLoader extends StatefulWidget {
  final double height;
  final BorderRadius borderRadius;

  const SkeletonLoader({
    super.key,
    this.height = 64,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceVariant;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: base.withOpacity(0.4 + (_controller.value * 0.3)),
            borderRadius: widget.borderRadius,
          ),
        );
      },
    );
  }
}

/// A vertical stack of [SkeletonLoader] rows, used while a list is loading.
class SkeletonList extends StatelessWidget {
  final int itemCount;

  const SkeletonList({super.key, this.itemCount = 4});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => const SkeletonLoader(),
    );
  }
}

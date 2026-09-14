import 'package:flutter/material.dart';

import 'shimmer_box.dart';

/// A grid of skeleton poster cards used while list data loads.
///
/// Replaces the default `CircularProgressIndicator` with a premium shimmer
/// placeholder so the layout feels populated and stable while content streams
/// in. Uses the existing [ShimmerBox] for a smooth, GPU-friendly shimmer.
class MovieCardSkeletonGrid extends StatelessWidget {
  final int itemCount;
  final int crossAxisCount;
  final double childAspectRatio;
  final EdgeInsetsGeometry padding;

  const MovieCardSkeletonGrid({
    super.key,
    this.itemCount = 6,
    this.crossAxisCount = 2,
    this.childAspectRatio = 0.7,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: padding,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: itemCount,
      itemBuilder: (_, _) => const _PosterSkeleton(),
    );
  }
}

/// A horizontal row of skeleton poster cards (used on the Home screen rows).
class MovieRowSkeleton extends StatelessWidget {
  final int itemCount;
  final double height;

  const MovieRowSkeleton({super.key, this.itemCount = 6, this.height = 302});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(width: 16),
        itemBuilder: (_, _) => const _PosterSkeleton(),
      ),
    );
  }
}

/// A single skeleton poster card (2:3 poster with title bars).
class _PosterSkeleton extends StatelessWidget {
  const _PosterSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBox(width: double.infinity, height: 225, radius: 18),
          const SizedBox(height: 10),
          ShimmerBox(width: 120, height: 14, radius: 6),
          const SizedBox(height: 8),
          ShimmerBox(width: 80, height: 11, radius: 6),
        ],
      ),
    );
  }
}

/// A full-width hero skeleton with title + button placeholders.
class HeroSkeleton extends StatelessWidget {
  final double height;
  const HeroSkeleton({super.key, this.height = 380});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ShimmerBox(height: double.infinity, radius: 0),
            Positioned(
              top: 16,
              left: 16,
              child: ShimmerBox(width: 110, height: 26, radius: 13),
            ),
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShimmerBox(width: 200, height: 26, radius: 6),
                  const SizedBox(height: 12),
                  ShimmerBox(width: 150, height: 14, radius: 6),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      ShimmerBox(width: 140, height: 46, radius: 12),
                      const SizedBox(width: 12),
                      ShimmerBox(width: 46, height: 46, radius: 12),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A simple shimmer block for page-level loading (e.g. details screen).
class DetailsSkeleton extends StatelessWidget {
  const DetailsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        const ShimmerBox(height: 380, radius: 0),
        Padding(
          padding: const EdgeInsets.all(20),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerBox(width: 200, height: 22, radius: 6),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ShimmerBox(width: 200, height: 48, radius: 12),
                  ShimmerBox(width: 80, height: 48, radius: 12),
                ],
              ),
              SizedBox(height: 24),
              ShimmerBox(height: 16, radius: 6),
              SizedBox(height: 12),
              ShimmerBox(height: 16, radius: 6),
              SizedBox(height: 12),
              ShimmerBox(width: 240, height: 16, radius: 6),
              SizedBox(height: 32),
              ShimmerBox(width: 160, height: 20, radius: 6),
              SizedBox(height: 16),
              SizedBox(
                height: 150,
                child: Row(
                  children: [
                    ShimmerBox(width: 72, height: 72, radius: 36),
                    SizedBox(width: 16),
                    ShimmerBox(width: 72, height: 72, radius: 36),
                    SizedBox(width: 16),
                    ShimmerBox(width: 72, height: 72, radius: 36),
                    SizedBox(width: 16),
                    ShimmerBox(width: 72, height: 72, radius: 36),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


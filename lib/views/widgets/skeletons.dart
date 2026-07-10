import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

const _base = Color(0xFFE7E5DE);
const _highlight = Color(0xFFF4F3EF);

/// Wraps [child] in an animated shimmer sweep. The child should be made of
/// solid placeholder shapes (see [_Box]); transparent areas stay untouched.
class Shimmer extends StatefulWidget {
  final Widget child;
  const Shimmer({super.key, required this.child});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: const [_base, _highlight, _base],
              stops: const [0.35, 0.5, 0.65],
              transform: _SlideTransform(_controller.value),
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}

class _SlideTransform extends GradientTransform {
  final double value; // 0..1
  const _SlideTransform(this.value);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final dx = bounds.width * (value * 2 - 1);
    return Matrix4.translationValues(dx, 0, 0);
  }
}

/// A non-scrolling column of placeholder recipe cards for loading states.
class RecipeListSkeleton extends StatelessWidget {
  final int count;
  final EdgeInsets padding;
  const RecipeListSkeleton({
    super.key,
    this.count = 4,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 24),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        children: List.generate(count, (_) => const _RecipeCardSkeleton()),
      ),
    );
  }
}

/// A shimmering column of simple checkbox rows for list loading states
/// (e.g. the shopping list).
class ListRowsSkeleton extends StatelessWidget {
  final int count;
  final EdgeInsets padding;
  const ListRowsSkeleton({
    super.key,
    this.count = 6,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 24),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Shimmer(
        child: Column(
          children: List.generate(
            count,
            (i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  const _Box(width: 24, height: 24, radius: 8),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _Box(
                        width: i.isEven ? null : 200, height: 14, radius: 6),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecipeCardSkeleton extends StatelessWidget {
  const _RecipeCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.line),
      ),
      child: Shimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Box(height: 180),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _Box(width: 180, height: 20, radius: 6),
                  SizedBox(height: 12),
                  _Box(height: 12, radius: 6),
                  SizedBox(height: 8),
                  _Box(width: 220, height: 12, radius: 6),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      _Box(width: 84, height: 28, radius: 30),
                      SizedBox(width: 8),
                      _Box(width: 84, height: 28, radius: 30),
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

class _Box extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  const _Box({this.width, required this.height, this.radius = 0});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: _base,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

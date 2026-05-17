// Profil ekranı yüklenirken gösterilen shimmer iskeleti.
part of '../profile_screen.dart';

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;

    return Shimmer.fromColors(
      baseColor: const Color(0xFF1A1D27),
      highlightColor: const Color(0xFF2A2D37),
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, topPadding + 16, 16, 24),
        children: [
          const _SkeletonBox(height: 244, radius: 30),
          const SizedBox(height: 18),
          Row(
            children: const [
              Expanded(child: _SkeletonBox(height: 134, radius: 18)),
              SizedBox(width: 10),
              Expanded(child: _SkeletonBox(height: 134, radius: 18)),
              SizedBox(width: 10),
              Expanded(child: _SkeletonBox(height: 134, radius: 18)),
            ],
          ),
          const SizedBox(height: 14),
          const _SkeletonBox(height: 160, radius: 18),
          const SizedBox(height: 14),
          const _SkeletonBox(height: 72, radius: 16),
          const SizedBox(height: 10),
          const _SkeletonBox(height: 72, radius: 16),
          const SizedBox(height: 10),
          const _SkeletonBox(height: 72, radius: 16),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double height;
  final double radius;

  const _SkeletonBox({required this.height, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// Tek bir yorumu (ve özyinelemeli olarak yanıtlarını) render eden kart.
// Reddit tarzı: renk kodlu thread çizgileri, profil fotoğrafı, animasyonlu
// daraltma ve makale yazarı (OP) vurgusu içerir.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/yorum_model.dart';
import 'linkified_text.dart';

// Seviye bazlı thread çizgi renkleri (her iç içe seviye farklı renk alır).
const List<Color> _threadColors = [
  Color(0xFF22D3EE), // cyan
  Color(0xFF6366F1), // indigo
  Color(0xFFF5A623), // amber
  Color(0xFF34D399), // yeşil
  Color(0xFFF472B6), // pembe
];

Color threadRengi(int depth) => _threadColors[depth % _threadColors.length];

class CommentTile extends StatelessWidget {
  final YorumModel yorum;
  final int depth;
  final String? opAuthorName;
  final bool canModerate;
  final int? currentUserId;
  final Set<int> collapsedIds;
  final ValueChanged<YorumModel> onReply;
  final ValueChanged<YorumModel> onLike;
  final ValueChanged<YorumModel> onDelete;
  final ValueChanged<int> onToggleCollapse;
  final ValueChanged<int?> onAuthorTap;

  const CommentTile({
    super.key,
    required this.yorum,
    required this.depth,
    required this.opAuthorName,
    required this.canModerate,
    required this.currentUserId,
    required this.collapsedIds,
    required this.onReply,
    required this.onLike,
    required this.onDelete,
    required this.onToggleCollapse,
    required this.onAuthorTap,
  });

  bool get _isOp =>
      opAuthorName != null &&
      opAuthorName != 'Anonim' &&
      yorum.yazarAdi == opAuthorName;

  @override
  Widget build(BuildContext context) {
    final collapsed = collapsedIds.contains(yorum.id);
    final hasReplies = yorum.yanitlar.isNotEmpty;
    final altYanitSayisi = yorum.yanitlar.fold<int>(
      0,
      (toplam, y) => toplam + y.toplamSayi,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _kart(context, collapsed, hasReplies, altYanitSayisi),
        if (hasReplies)
          ClipRect(
            child: AnimatedAlign(
              alignment: Alignment.topCenter,
              heightFactor: collapsed ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: AnimatedOpacity(
                opacity: collapsed ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, left: 6),
                  child: Container(
                    padding: const EdgeInsets.only(left: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: threadRengi(depth).withValues(alpha: 0.55),
                          width: 2.5,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: yorum.yanitlar
                          .map(
                            (y) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: CommentTile(
                                key: ValueKey('yorum-${y.id}'),
                                yorum: y,
                                depth: depth + 1,
                                opAuthorName: opAuthorName,
                                canModerate: canModerate,
                                currentUserId: currentUserId,
                                collapsedIds: collapsedIds,
                                onReply: onReply,
                                onLike: onLike,
                                onDelete: onDelete,
                                onToggleCollapse: onToggleCollapse,
                                onAuthorTap: onAuthorTap,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _kart(
    BuildContext context,
    bool collapsed,
    bool hasReplies,
    int altYanitSayisi,
  ) {
    final canDelete = canModerate || currentUserId == yorum.yazarId;
    final bg = _isOp
        ? AppTheme.primary.withValues(alpha: 0.07)
        : Colors.white.withValues(alpha: 0.035);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isOp
              ? AppTheme.primary.withValues(alpha: 0.30)
              : Colors.white.withValues(alpha: 0.07),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Makale yazarının yorumlarında sol accent şeridi.
            if (_isOp) Container(width: 3.5, color: AppTheme.primary),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _baslik(canDelete),
                    const SizedBox(height: 9),
                    LinkifiedText(
                      text: yorum.mesaj,
                      baseStyle: const TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                      linkColor: const Color(0xFF22D3EE),
                    ),
                    const SizedBox(height: 10),
                    _aksiyonlar(),
                    if (hasReplies) ...[
                      const SizedBox(height: 8),
                      _yanitToggle(collapsed, altYanitSayisi),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _baslik(bool canDelete) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => onAuthorTap(yorum.yazarId),
          borderRadius: BorderRadius.circular(20),
          child: _avatar(),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: InkWell(
                      onTap: () => onAuthorTap(yorum.yazarId),
                      child: Text(
                        yorum.yazarAdi,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ),
                  if (_isOp) ...[
                    const SizedBox(width: 6),
                    _opRozeti(),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                yorum.tarihGoreli,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.44),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (canDelete)
          SizedBox(
            height: 32,
            width: 32,
            child: PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              tooltip: 'Moderasyon',
              icon: Icon(
                Icons.more_horiz,
                size: 20,
                color: Colors.white.withValues(alpha: 0.5),
              ),
              onSelected: (value) {
                if (value == 'delete') onDelete(yorum);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                      SizedBox(width: 8),
                      Text('Sil'),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _avatar() {
    final initial = yorum.yazarAdi.trim().isEmpty
        ? '?'
        : yorum.yazarAdi.trim().substring(0, 1).toUpperCase();
    final fallback = Container(
      color: const Color(0xFF22D3EE).withValues(alpha: 0.14),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Color(0xFFBFF6FF),
          fontSize: 15,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
    final url = yorum.avatarUrl;

    return SizedBox(
      width: 40,
      height: 40,
      child: ClipOval(
        child: url == null
            ? fallback
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (context, _) => fallback,
                errorWidget: (context, _, _) => fallback,
              ),
      ),
    );
  }

  Widget _opRozeti() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.45)),
      ),
      child: const Text(
        'YAZAR',
        style: TextStyle(
          color: AppTheme.primary,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _aksiyonlar() {
    return Row(
      children: [
        _aksiyon(
          icon: yorum.begendim ? Icons.favorite : Icons.favorite_border,
          label: '${yorum.begeniSayisi}',
          color: yorum.begendim
              ? const Color(0xFFEF4444)
              : Colors.white.withValues(alpha: 0.56),
          onTap: () => onLike(yorum),
        ),
        const SizedBox(width: 6),
        _aksiyon(
          icon: Icons.mode_comment_outlined,
          label: 'Yanitla',
          color: const Color(0xFF22D3EE),
          onTap: () => onReply(yorum),
        ),
      ],
    );
  }

  Widget _aksiyon({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Reddit tarzı satır içi "── X yanıtı göster ──" bağlantısı.
  Widget _yanitToggle(bool collapsed, int altYanitSayisi) {
    final renk = threadRengi(depth);
    return InkWell(
      onTap: () => onToggleCollapse(yorum.id),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 1,
                color: renk.withValues(alpha: 0.22),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    collapsed ? Icons.expand_more : Icons.expand_less,
                    size: 15,
                    color: renk,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    collapsed
                        ? '$altYanitSayisi yanıtı göster'
                        : 'Yanıtları gizle',
                    style: TextStyle(
                      color: renk,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      decoration: TextDecoration.underline,
                      decorationColor: renk.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                height: 1,
                color: renk.withValues(alpha: 0.22),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

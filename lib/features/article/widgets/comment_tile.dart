// Tek bir yorumu (ve özyinelemeli olarak yanıtlarını) render eden kart.
// Reddit tarzı: renk kodlu thread çizgileri, profil fotoğrafı, animasyonlu
// daraltma ve makale yazarı (OP) vurgusu içerir.
// Yanıtlar: widget.yorum.yanitlar ile geldiyse doğrudan gösterir;
// boşsa "yanıtları göster" tıklandığında API'den lazy yükler.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/api_service.dart';
import '../../../shared/models/yorum_model.dart';
import 'comment_skeleton.dart';
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

const int defaultMaxInlineCommentDepth = 2;

class CommentTile extends StatefulWidget {
  final YorumModel yorum;
  final int depth;
  final int maxInlineDepth;
  final String? opAuthorName;
  final bool canModerate;
  final int? currentUserId;
  final Set<int> expandedIds;
  final ValueChanged<YorumModel> onReply;
  final ValueChanged<YorumModel> onLike;
  final ValueChanged<YorumModel> onDelete;
  final ValueChanged<int> onToggleCollapse;
  final ValueChanged<int?> onAuthorTap;
  final ValueChanged<YorumModel>? onContinueThread;

  const CommentTile({
    super.key,
    required this.yorum,
    required this.depth,
    this.maxInlineDepth = defaultMaxInlineCommentDepth,
    required this.opAuthorName,
    required this.canModerate,
    required this.currentUserId,
    required this.expandedIds,
    required this.onReply,
    required this.onLike,
    required this.onDelete,
    required this.onToggleCollapse,
    required this.onAuthorTap,
    this.onContinueThread,
  });

  @override
  State<CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<CommentTile> {
  // Yanıtlar widget.yorum.yanitlar'dan geldiyse doğrudan kullan.
  // Boşsa API'den lazy yükle.
  late List<YorumModel> _replies;
  bool _isLoadingReplies = false;
  bool _hasCheckedApi = false;
  // Yalnızca API'den yüklenen yanıtların görünürlüğü (_showApiReplies).
  // Pre-loaded yanıtlar collapsedIds mekanizmasıyla yönetilir.
  bool _showApiReplies = false;

  bool get _isOp =>
      widget.opAuthorName != null &&
      widget.opAuthorName != 'Anonim' &&
      widget.yorum.yazarAdi == widget.opAuthorName;

  @override
  void initState() {
    super.initState();
    _replies = widget.yorum.yanitlar;
    // Yanıtlar model üzerinden zaten geldiyse API kontrolüne gerek yok.
    _hasCheckedApi = widget.yorum.yanitlar.isNotEmpty;
  }

  Future<void> _fetchReplies() async {
    if (_isLoadingReplies || _hasCheckedApi) return;
    if (widget.depth >= widget.maxInlineDepth) return;
    setState(() => _isLoadingReplies = true);
    try {
      final apiService = ApiService();
      final yanitlar = await apiService.getYanitlar(widget.yorum.id);
      if (!mounted) return;
      setState(() {
        _replies = yanitlar;
        _hasCheckedApi = true;
        _isLoadingReplies = false;
        _showApiReplies = yanitlar.isNotEmpty;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasCheckedApi = true;
        _isLoadingReplies = false;
      });
    }
  }

  void _handleToggle() {
    if (widget.depth >= widget.maxInlineDepth) {
      widget.onContinueThread?.call(widget.yorum);
      return;
    }
    if (widget.yorum.yanitlar.isNotEmpty) {
      // Pre-loaded: mevcut collapse mekanizmasını kullan.
      widget.onToggleCollapse(widget.yorum.id);
    } else if (!_hasCheckedApi) {
      // Henüz yüklenmedi: API'den getir.
      _fetchReplies();
    } else {
      // API kontrolü yapıldı: toggle göster/gizle.
      setState(() => _showApiReplies = !_showApiReplies);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expanded = widget.expandedIds.contains(widget.yorum.id);
    final canInlineReplies = widget.depth < widget.maxInlineDepth;

    // Gösterilecek yanıtlar: pre-loaded ise widget.yorum.yanitlar,
    // API'den geldiyse _replies.
    final effectiveReplies = widget.yorum.yanitlar.isNotEmpty
        ? widget.yorum.yanitlar
        : _replies;

    final hasKnownReplies =
        effectiveReplies.isNotEmpty ||
        widget.yorum.yanitSayisi > 0 ||
        widget.yorum.toplamYanitSayisi > 0 ||
        widget.yorum.hasMoreReplies ||
        _isLoadingReplies;
    final hasInlineReplyControl = canInlineReplies && hasKnownReplies;
    final hasContinuation =
        !canInlineReplies && hasKnownReplies && widget.onContinueThread != null;

    // Yanıtlar gösterilecek mi?
    final showReplies = hasInlineReplyControl
        ? (widget.yorum.yanitlar.isNotEmpty ? expanded : _showApiReplies)
        : false;

    final localReplyCount = effectiveReplies.fold<int>(
      0,
      (toplam, y) => toplam + y.toplamSayi,
    );
    final altYanitSayisi = widget.yorum.toplamYanitSayisi > 0
        ? widget.yorum.toplamYanitSayisi
        : localReplyCount > 0
        ? localReplyCount
        : widget.yorum.yanitSayisi;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _kart(
          context,
          expanded,
          hasInlineReplyControl,
          hasContinuation,
          altYanitSayisi,
        ),
        if (hasInlineReplyControl)
          ClipRect(
            child: AnimatedAlign(
              alignment: Alignment.topCenter,
              heightFactor: showReplies ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: AnimatedOpacity(
                opacity: showReplies ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, left: 6),
                  child: Container(
                    padding: const EdgeInsets.only(left: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: threadRengi(
                            widget.depth,
                          ).withValues(alpha: 0.55),
                          width: 2.5,
                        ),
                      ),
                    ),
                    child: _isLoadingReplies
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: CommentSkeletonList(adet: 2),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: effectiveReplies
                                .map(
                                  (y) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: CommentTile(
                                      key: ValueKey('yorum-${y.id}'),
                                      yorum: y,
                                      depth: widget.depth + 1,
                                      maxInlineDepth: widget.maxInlineDepth,
                                      opAuthorName: widget.opAuthorName,
                                      canModerate: widget.canModerate,
                                      currentUserId: widget.currentUserId,
                                      expandedIds: widget.expandedIds,
                                      onReply: widget.onReply,
                                      onLike: widget.onLike,
                                      onDelete: widget.onDelete,
                                      onToggleCollapse: widget.onToggleCollapse,
                                      onAuthorTap: widget.onAuthorTap,
                                      onContinueThread: widget.onContinueThread,
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
    bool expanded,
    bool hasInlineReplyControl,
    bool hasContinuation,
    int altYanitSayisi,
  ) {
    final canDelete =
        widget.canModerate || widget.currentUserId == widget.yorum.yazarId;
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
                      text: widget.yorum.mesaj,
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
                    if (hasContinuation) ...[
                      const SizedBox(height: 8),
                      _devamButonu(altYanitSayisi),
                    ] else if (hasInlineReplyControl) ...[
                      const SizedBox(height: 8),
                      _yanitToggle(expanded, altYanitSayisi),
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
          onTap: () => widget.onAuthorTap(widget.yorum.yazarId),
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
                      onTap: () => widget.onAuthorTap(widget.yorum.yazarId),
                      child: Text(
                        widget.yorum.yazarAdi,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ),
                  if (_isOp) ...[const SizedBox(width: 6), _opRozeti()],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                widget.yorum.tarihGoreli,
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
                if (value == 'delete') widget.onDelete(widget.yorum);
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
    final initial = widget.yorum.yazarAdi.trim().isEmpty
        ? '?'
        : widget.yorum.yazarAdi.trim().substring(0, 1).toUpperCase();
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
    final url = widget.yorum.avatarUrl;

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
          icon: widget.yorum.begendim ? Icons.favorite : Icons.favorite_border,
          label: '${widget.yorum.begeniSayisi}',
          color: widget.yorum.begendim
              ? const Color(0xFFEF4444)
              : Colors.white.withValues(alpha: 0.56),
          onTap: () => widget.onLike(widget.yorum),
        ),
        const SizedBox(width: 6),
        _aksiyon(
          icon: Icons.mode_comment_outlined,
          label: 'Yanıtla',
          color: const Color(0xFF22D3EE),
          onTap: () => widget.onReply(widget.yorum),
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

  Widget _devamButonu(int altYanitSayisi) {
    final renk = threadRengi(widget.depth);
    final sayiMetni = altYanitSayisi > 0 ? ' ($altYanitSayisi)' : '';

    return InkWell(
      onTap: () => widget.onContinueThread?.call(widget.yorum),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: renk.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: renk.withValues(alpha: 0.24)),
        ),
        child: Row(
          children: [
            Icon(Icons.arrow_forward_rounded, size: 17, color: renk),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Bu tartışmanın devamını gör$sayiMetni',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: renk,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _yanitToggle(bool expanded, int altYanitSayisi) {
    final renk = threadRengi(widget.depth);

    // Pre-loaded yanıtlar collapse mekanizmasını kullanır.
    // API'den gelen yanıtlar _showApiReplies'i kullanır.
    final gizlendi = widget.yorum.yanitlar.isNotEmpty
        ? !expanded
        : !_showApiReplies;

    final etiket = _isLoadingReplies
        ? 'Yükleniyor...'
        : gizlendi
        ? '$altYanitSayisi yanıtı göster'
        : 'Yanıtları gizle';

    return InkWell(
      onTap: _handleToggle,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
              child: Container(height: 1, color: renk.withValues(alpha: 0.22)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _isLoadingReplies
                      ? SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: renk,
                          ),
                        )
                      : Icon(
                          gizlendi ? Icons.expand_more : Icons.expand_less,
                          size: 15,
                          color: renk,
                        ),
                  const SizedBox(width: 4),
                  Text(
                    etiket,
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
              child: Container(height: 1, color: renk.withValues(alpha: 0.22)),
            ),
          ],
        ),
      ),
    );
  }
}

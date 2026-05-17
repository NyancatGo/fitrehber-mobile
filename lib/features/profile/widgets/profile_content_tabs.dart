// Profil ekranındaki "İçerikler" sekme bölümü.
// Paylaşımlar (herkese açık), Kaydedilenler ve Beğenilenler (yalnızca sahibi).
// Her sekme sayfalı (infinite scroll) çalışır ve sekme değişiminde durumunu korur.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/api_service.dart';
import '../../../shared/hata_yardimcilari.dart';
import '../../../shared/models/icerik_model.dart';
import '../../../shared/models/paginated_response.dart';
import '../../../shared/models/yorum_model.dart';
import '../../../shared/pagination/pagination_helpers.dart';
import '../providers/profile_provider.dart';

class ProfileContentTabs extends ConsumerStatefulWidget {
  final int userId;
  final bool isOwnProfile;

  const ProfileContentTabs({
    super.key,
    required this.userId,
    required this.isOwnProfile,
  });

  @override
  ConsumerState<ProfileContentTabs> createState() => _ProfileContentTabsState();
}

class _ProfileContentTabsState extends ConsumerState<ProfileContentTabs>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  // Merkezi Dio konfigürasyonu paylaşılsın diye ApiService Riverpod'dan alınır.
  late final ApiService _api;

  @override
  void initState() {
    super.initState();
    _api = ref.read(profileApiProvider);
    _tabController = TabController(
      length: widget.isOwnProfile ? 3 : 1,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Tab>[
      const Tab(text: 'Paylaşımlar'),
      if (widget.isOwnProfile) const Tab(text: 'Kaydedilenler'),
      if (widget.isOwnProfile) const Tab(text: 'Beğenilenler'),
    ];

    // Sabit yükseklik yerine ekran boyutuna göre uyarlanır; küçük cihazlarda
    // daha kompakt, büyük ekranlarda daha ferah görünür.
    final tabHeight = (MediaQuery.sizeOf(context).height * 0.6).clamp(
      360.0,
      640.0,
    );

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            isScrollable: tabs.length > 2,
            tabAlignment: tabs.length > 2
                ? TabAlignment.start
                : TabAlignment.fill,
            labelColor: AppTheme.primary,
            indicatorColor: AppTheme.primary,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.5),
            tabs: tabs,
          ),
          SizedBox(
            height: tabHeight,
            child: TabBarView(
              controller: _tabController,
              children: [
                _PaginatedListView<IcerikModel>(
                  loader: (page) =>
                      _api.getProfilIcerikleri(widget.userId, page: page),
                  emptyText: widget.isOwnProfile
                      ? 'Henüz paylaşımın yok.'
                      : 'Henüz paylaşım yok.',
                  itemBuilder: (context, item) => _IcerikSatiri(icerik: item),
                ),
                if (widget.isOwnProfile)
                  _PaginatedListView<IcerikModel>(
                    loader: (page) =>
                        _api.getProfilKaydedilenler(widget.userId, page: page),
                    emptyText: 'Henüz içerik kaydetmedin.',
                    itemBuilder: (context, item) => _IcerikSatiri(icerik: item),
                  ),
                if (widget.isOwnProfile)
                  _PaginatedListView<YorumOzetModel>(
                    loader: (page) =>
                        _api.getProfilBegeniler(widget.userId, page: page),
                    emptyText: 'Henüz yorum beğenmedin.',
                    itemBuilder: (context, item) => _BegeniSatiri(yorum: item),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaginatedListView<T> extends StatefulWidget {
  final Future<PaginatedResponse<T>> Function(int page) loader;
  final Widget Function(BuildContext, T) itemBuilder;
  final String emptyText;

  const _PaginatedListView({
    required this.loader,
    required this.itemBuilder,
    required this.emptyText,
  });

  @override
  State<_PaginatedListView<T>> createState() => _PaginatedListViewState<T>();
}

class _PaginatedListViewState<T> extends State<_PaginatedListView<T>>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final PaginationTrigger _paginationTrigger = PaginationTrigger();
  final List<T> _items = [];

  int _page = 1;
  bool _ilkYukleniyor = true;
  bool _dahaYukleniyor = false;
  bool _dahaVar = true;
  String? _hata;

  // Sekme değiştirildiğinde state (scroll konumu, yüklenmiş sayfalar) korunur.
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _ilkYukle();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_paginationTrigger.shouldLoad(_scrollController, threshold: 240)) {
      _dahaYukle();
    }
  }

  Future<void> _ilkYukle() async {
    setState(() {
      _ilkYukleniyor = true;
      _hata = null;
    });
    try {
      final response = await widget.loader(1);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(response.results);
        _page = 1;
        _dahaVar = response.hasNext;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = kullaniciDostuHata(e));
    } finally {
      if (mounted) setState(() => _ilkYukleniyor = false);
    }
  }

  Future<void> _dahaYukle() async {
    if (_dahaYukleniyor || !_dahaVar || _ilkYukleniyor) return;
    setState(() => _dahaYukleniyor = true);
    try {
      final response = await widget.loader(_page + 1);
      if (!mounted) return;
      setState(() {
        _page += 1;
        _items.addAll(response.results);
        _dahaVar = response.hasNext;
      });
    } catch (_) {
      if (mounted) showPaginationLoadErrorSnack(context, onRetry: _dahaYukle);
    } finally {
      if (mounted) setState(() => _dahaYukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_ilkYukleniyor) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_hata != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _hata!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: _ilkYukle, child: const Text('Tekrar Dene')),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _ilkYukle,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 90),
            Center(
              child: Text(
                widget.emptyText,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _ilkYukle,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount: _items.length + (_dahaVar ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          return widget.itemBuilder(context, _items[index]);
        },
      ),
    );
  }
}

class _IcerikSatiri extends StatelessWidget {
  final IcerikModel icerik;

  const _IcerikSatiri({required this.icerik});

  @override
  Widget build(BuildContext context) {
    final forumMu = icerik.tur == 'soru';
    return Card(
      key: ValueKey('profil-icerik-${icerik.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: icerik.resimUrl != null && icerik.resimUrl!.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: icerik.resimUrl!,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  placeholder: (c, u) =>
                      Container(color: const Color(0xFF2A2D37)),
                  errorWidget: (c, u, e) => const Icon(Icons.image),
                ),
              )
            : Icon(
                forumMu ? Icons.forum_outlined : Icons.article_outlined,
                color: const Color(0xFF22D3EE),
              ),
        title: Text(
          icerik.baslik,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        subtitle: Text(
          '${forumMu ? 'Forum' : icerik.kategoriAdi} · ${icerik.tarihFormatli}',
          style: const TextStyle(fontSize: 12),
        ),
        onTap: () => context.push('/makale/${icerik.id}'),
      ),
    );
  }
}

class _BegeniSatiri extends StatelessWidget {
  final YorumOzetModel yorum;

  const _BegeniSatiri({required this.yorum});

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey('profil-begeni-${yorum.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: const Icon(Icons.favorite, color: Color(0xFFEF4444)),
        title: Text(
          yorum.mesaj,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          yorum.icerikBaslik.isEmpty
              ? '${yorum.yazarAdi} · yorum'
              : '${yorum.yazarAdi} · ${yorum.icerikBaslik}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
        onTap: yorum.icerikId == null
            ? null
            : () => context.push('/makale/${yorum.icerikId}'),
      ),
    );
  }
}

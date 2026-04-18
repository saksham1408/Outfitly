import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/theme.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../domain/models/app_category.dart';
import '../../domain/models/sub_category.dart';
import '../widgets/category_row_shimmer.dart';
import '../widgets/error_retry.dart';
import '../widgets/sub_category_row.dart';
import 'widgets/home_sticky_header.dart';

/// Screen states: Loading → Data / Error.
enum _LoadState { loading, data, error }

/// The Home screen shows only:
///   • Top tabs (MEN / WOMEN / KIDS)
///   • Horizontal list of subcategory circles
///   • Hero banner
///
/// Tapping a subcategory pushes the user into a dedicated PLP
/// (`SubcategoryScreen`) via `/subcategory/:id`. The product grid itself
/// lives on that dedicated screen, not here.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  final _repo = CatalogRepository();

  // Top categories
  List<AppCategory> _topCategories = [];
  _LoadState _topCategoryState = _LoadState.loading;
  String? _topCategoryError;

  // Per-tab subcategory state
  final Map<String, List<SubCategory>> _subCatsByTop = {};
  final Map<String, _LoadState> _subCatStateByTop = {};

  TabController? _tabController;
  int _activeIndex = 0;
  bool _userTappedTab = false;

  @override
  void initState() {
    super.initState();
    _loadTopCategories();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  AppCategory? get _activeCategory =>
      _topCategories.isNotEmpty ? _topCategories[_activeIndex] : null;

  Future<void> _loadTopCategories() async {
    setState(() {
      _topCategoryState = _LoadState.loading;
      _topCategoryError = null;
    });

    try {
      final cats = await _repo.getTopCategories();
      if (!mounted) return;

      _tabController?.dispose();
      _tabController = TabController(length: cats.length, vsync: this);
      _tabController!.addListener(() {
        if (_tabController!.indexIsChanging) return;
        _onTabSelected(_tabController!.index);
      });

      setState(() {
        _topCategories = cats;
        _activeIndex = 0;
        _topCategoryState = _LoadState.data;
      });

      if (cats.isNotEmpty) {
        _ensureSubCategoriesLoaded(cats.first.id);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _topCategoryError = e.toString();
        _topCategoryState = _LoadState.error;
      });
    }
  }

  void _onTabSelected(int index) {
    final cat = _topCategories[index];
    setState(() {
      _activeIndex = index;
      _userTappedTab = true;
    });
    _ensureSubCategoriesLoaded(cat.id);
  }

  /// Push the dedicated PLP for the tapped subcategory.
  /// The subcategory name is passed via `extra` so the new screen can show
  /// it in the AppBar without an extra network round-trip.
  void _onSubCategoryTapped(SubCategory sub) {
    context.push('/subcategory/${sub.id}', extra: sub.name);
  }

  Future<void> _ensureSubCategoriesLoaded(String categoryId) async {
    if (_subCatsByTop.containsKey(categoryId) &&
        _subCatStateByTop[categoryId] == _LoadState.data) {
      return;
    }
    setState(() {
      _subCatStateByTop[categoryId] = _LoadState.loading;
    });
    try {
      final subs = await _repo.getSubCategories(categoryId);
      if (!mounted) return;
      setState(() {
        _subCatsByTop[categoryId] = subs;
        _subCatStateByTop[categoryId] = _LoadState.data;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _subCatStateByTop[categoryId] = _LoadState.error);
    }
  }

  Future<void> _refresh() async {
    final active = _activeCategory;
    if (active == null) {
      await _loadTopCategories();
      return;
    }
    _subCatsByTop.remove(active.id);
    await _ensureSubCategoriesLoaded(active.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_topCategoryState == _LoadState.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_topCategoryState == _LoadState.error || _topCategories.isEmpty) {
      return ErrorRetry(
        message:
            _topCategoryError ?? 'Failed to load catalog. Please try again.',
        onRetry: _loadTopCategories,
      );
    }

    final active = _activeCategory!;
    final subState = _subCatStateByTop[active.id];
    final subs = _subCatsByTop[active.id] ?? [];

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.accent,
      child: CustomScrollView(
        slivers: [
          // Sticky header (top bar + gender tabs)
          SliverPersistentHeader(
            pinned: true,
            delegate: HomeStickyHeader(
              tabController: _tabController!,
              tabLabels: _topCategories.map((c) => c.name).toList(),
              onSearchTap: () => context.push('/search'),
              onNotificationTap: () {},
              onProfileTap: () => context.push('/profile'),
              onTabTap: _onTabSelected,
            ),
          ),

          // Subcategory row — shown once user taps a tab
          if (_userTappedTab) ...[
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
              child: _buildSubCategoryRow(subState, subs, active),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
          ] else
            const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // Hero banner
          SliverToBoxAdapter(child: _buildHeroBanner()),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildSubCategoryRow(
      _LoadState? state, List<SubCategory> subs, AppCategory active) {
    if (state == _LoadState.loading) return const CategoryRowShimmer();
    if (state == _LoadState.error) {
      return SizedBox(
        height: 96,
        child: Center(
          child: TextButton.icon(
            onPressed: () => _ensureSubCategoriesLoaded(active.id),
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(
              'Retry subcategories',
              style: GoogleFonts.manrope(fontSize: 12),
            ),
          ),
        ),
      );
    }
    if (subs.isEmpty) {
      return SizedBox(
        height: 80,
        child: Center(
          child: Text(
            'No subcategories yet.',
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
          ),
        ),
      );
    }
    return SubCategoryRow(
      subCategories: subs,
      // No persistent selection on Home — each tap navigates away to the PLP.
      selectedId: null,
      onTap: _onSubCategoryTapped,
    );
  }

  Widget _buildHeroBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Craft Your\nSignature Look',
              style: GoogleFonts.newsreader(
                fontSize: 24,
                fontStyle: FontStyle.italic,
                color: Colors.white,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Custom-stitched from fabric to finish',
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: Colors.white.withAlpha(200),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

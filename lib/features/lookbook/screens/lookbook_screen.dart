import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme.dart';
import '../models/lookbook_item_model.dart';
import '../services/lookbook_service.dart';
import '../widgets/lookbook_card.dart';

class LookbookScreen extends StatefulWidget {
  const LookbookScreen({super.key});

  @override
  State<LookbookScreen> createState() => _LookbookScreenState();
}

class _LookbookScreenState extends State<LookbookScreen> {
  final _service = LookbookService();

  List<LookbookItemModel> _items = [];
  List<String> _categories = [];
  String? _selectedCategory;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _service.getAllItems(),
        _service.getCategories(),
      ]);
      if (!mounted) return;
      setState(() {
        _items = results[0] as List<LookbookItemModel>;
        _categories = results[1] as List<String>;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _filterByCategory(String? category) async {
    setState(() {
      _selectedCategory = category;
      _loading = true;
    });
    try {
      final items = category != null
          ? await _service.getItemsByCategory(category)
          : await _service.getAllItems();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: AppColors.background,
            elevation: 0,
            title: Text(
              'Lookbook',
              style: GoogleFonts.newsreader(
                fontSize: 28,
                fontStyle: FontStyle.italic,
                color: AppColors.primary,
              ),
            ),
            actions: [
              IconButton(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded, size: 22),
              ),
            ],
          ),

          // ── Subtitle ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 2, width: 48, color: AppColors.accent),
                  const SizedBox(height: 10),
                  Text(
                    'Curated fabrics for the discerning eye. Each piece handpicked for quality, texture and craft.',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Category Filters ──
          if (_categories.isNotEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _categories.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _filterChip('All', _selectedCategory == null, () {
                        _filterByCategory(null);
                      });
                    }
                    final cat = _categories[index - 1];
                    return _filterChip(
                      cat,
                      _selectedCategory == cat,
                      () => _filterByCategory(cat),
                    );
                  },
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // ── Items ──
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_items.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text(
                  'No items in this collection yet.',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = _items[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: LookbookCard(
                        item: item,
                        onTap: () => context.push('/lookbook/${item.id}'),
                      ),
                    );
                  },
                  childCount: _items.length,
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

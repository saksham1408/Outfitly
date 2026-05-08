import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'editorial_section_header.dart';

/// "The Edit" — a horizontal carousel of curated collections.
///
/// Each card is a tall portrait tile with a unique gradient
/// palette + serif italic display title + a Manrope caption +
/// piece-count chip. Tap routes to `/catalog`. The collections
/// are hand-picked (not table-driven) so the merchandising team
/// can swap the strings + palettes without a migration; in
/// production these would live in a Postgres `collections`
/// table or Directus-backed CMS.
///
/// Visual reference: this is the "lookbook entry" pattern used
/// by Tatacliq Luxe, Nykaa Fashion, and Pernia's Pop-Up — the
/// signal that says "we curate, we don't just dump products".
class FeaturedCollectionsRow extends StatelessWidget {
  const FeaturedCollectionsRow({super.key});

  static const _collections = <_FeaturedCollection>[
    _FeaturedCollection(
      title: 'Bridal Couture',
      caption: 'Hand-zardozi · 24 pieces',
      eyebrow: 'WEDDING',
      icon: Icons.diamond_outlined,
      gradient: [Color(0xFF7A2E1F), Color(0xFFB8856B)],
    ),
    _FeaturedCollection(
      title: 'Festive Edit',
      caption: 'Diwali · Karwa Chauth · Eid',
      eyebrow: 'IN SEASON',
      icon: Icons.auto_awesome_outlined,
      gradient: [Color(0xFF3B1A4F), Color(0xFFB8860B)],
    ),
    _FeaturedCollection(
      title: 'Heritage Crafts',
      caption: 'Banarasi · Tussar · Brocade',
      eyebrow: 'HANDLOOM',
      icon: Icons.spa_outlined,
      gradient: [Color(0xFF2F4A2A), Color(0xFFB8CFA3)],
    ),
    _FeaturedCollection(
      title: 'Indo-Western',
      caption: 'Modern silhouettes · Old-money palette',
      eyebrow: 'NEW DROP',
      icon: Icons.checkroom_rounded,
      gradient: [Color(0xFF1F3A57), Color(0xFF6B7C8E)],
    ),
    _FeaturedCollection(
      title: 'Wedding Guest',
      caption: 'Sage · Champagne · Blush',
      eyebrow: 'CURATED',
      icon: Icons.favorite_outline_rounded,
      gradient: [Color(0xFFB8856B), Color(0xFFE8D5B8)],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EditorialSectionHeader(
          eyebrow: 'Curated',
          title: 'The Edit',
          caption:
              'Lookbooks built around occasion, palette, and craft — slip into one.',
          actionLabel: 'See all',
          onActionTap: () => context.push('/catalog'),
        ),
        SizedBox(
          height: 220,
          child: ListView.separated(
            // Slightly past the screen edge on the left so the
            // first card lines up with the section header padding.
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: _collections.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              return _CollectionCard(collection: _collections[i]);
            },
          ),
        ),
      ],
    );
  }
}

class _FeaturedCollection {
  const _FeaturedCollection({
    required this.title,
    required this.caption,
    required this.eyebrow,
    required this.icon,
    required this.gradient,
  });

  final String title;
  final String caption;
  final String eyebrow;
  final IconData icon;
  final List<Color> gradient;
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({required this.collection});

  final _FeaturedCollection collection;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/catalog'),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 168,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: collection.gradient,
            ),
            boxShadow: [
              BoxShadow(
                color: collection.gradient.first.withAlpha(80),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Subtle decorative circle — adds depth without
              // needing a real image. Sits behind everything,
              // alpha-blended.
              Positioned(
                top: -30,
                right: -30,
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withAlpha(30),
                  ),
                ),
              ),
              Positioned(
                bottom: -20,
                left: -20,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withAlpha(15),
                  ),
                ),
              ),

              // Top-right: tiny eyebrow chip.
              Positioned(
                top: 14,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(40),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withAlpha(80),
                    ),
                  ),
                  child: Text(
                    collection.eyebrow,
                    style: GoogleFonts.manrope(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              // Top-left: oversized icon block.
              Positioned(
                top: 18,
                left: 16,
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(45),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    collection.icon,
                    size: 24,
                    color: Colors.white,
                  ),
                ),
              ),

              // Bottom — title + caption + arrow.
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      collection.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.newsreader(
                        fontSize: 19,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                        height: 1.05,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            collection.caption,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 10.5,
                              color: Colors.white.withAlpha(220),
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withAlpha(50),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

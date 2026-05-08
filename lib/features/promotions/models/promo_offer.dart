import 'package:flutter/foundation.dart';

/// Slide-design discriminator for the Home hero carousel.
///
/// Maps to the `offer_type` column on `public.promo_offers`
/// (added in migration 041). Two variants today:
///   * [sale]      — flash-sale slide: banner image + countdown.
///   * [bankOffer] — premium credit-card-style slide: metallic
///                   gradient + copy-code CTA.
///
/// Default to [sale] for any unknown / missing string so an
/// in-progress schema change can't crash the carousel.
enum OfferType {
  sale,
  bankOffer;

  static OfferType fromDb(String? raw) {
    switch (raw) {
      case 'bank_offer':
        return OfferType.bankOffer;
      case 'sale':
      default:
        return OfferType.sale;
    }
  }

  String get dbValue {
    switch (this) {
      case OfferType.sale:
        return 'sale';
      case OfferType.bankOffer:
        return 'bank_offer';
    }
  }
}

/// One row from `public.promo_offers` — a sitewide marketing
/// campaign surfaced on the customer "Active Offers & Sales"
/// dashboard *and* the new Home hero carousel.
///
/// The model is read-only on the customer client; rows are
/// authored by the marketing team via Directus and the customer
/// app only ever fetches them.
@immutable
class PromoOffer {
  const PromoOffer({
    required this.id,
    required this.title,
    required this.discountPercentage,
    required this.endDate,
    required this.isActive,
    required this.createdAt,
    required this.offerType,
    this.description,
    this.bannerImageUrl,
    this.targetRoute,
    this.promoCode,
    this.bankName,
  });

  final String id;
  final String title;
  final String? description;

  /// 1 → 99. Server CHECK pins the bounds; the UI renders this as
  /// "GET 20% OFF" on the banner card.
  final int discountPercentage;

  final String? bannerImageUrl;

  /// Local DateTime — converted from the column's UTC value at
  /// fromMap-time so the countdown timer works in the user's
  /// timezone without any extra coercion in the widget tree.
  final DateTime endDate;

  /// Optional deep-link route the offer card should push the
  /// user into when tapped. Free-form so marketing can target
  /// any in-app surface ('/catalog', '/subcategory/[id]', etc.)
  /// without us shipping a migration per route.
  final String? targetRoute;

  /// Optional promo code the design studio can pre-apply when
  /// the customer lands from this offer.
  final String? promoCode;

  /// True if the offer is currently published. The dashboard's
  /// query filters on this AND `endDate > now()` — the
  /// [isLive] getter combines both so the UI doesn't re-derive.
  final bool isActive;

  final DateTime createdAt;

  /// Slide-design discriminator. Drives whether the carousel
  /// renders a flash-sale layout or a metallic bank-offer card.
  final OfferType offerType;

  /// Issuer label rendered as a watermark on bank-offer slides
  /// (e.g. "HDFC", "SBI"). Always null when [offerType] is
  /// [OfferType.sale]; the column is allowed to hold any value
  /// in the database but the carousel only reads it for
  /// bank-offer rows.
  final String? bankName;

  /// True iff the offer is published AND not yet expired. The
  /// dashboard renders only live offers; an expired-but-active
  /// row would otherwise tease a deal the customer can't claim.
  bool get isLive {
    return isActive && endDate.isAfter(DateTime.now());
  }

  /// Time left until the countdown timer hits zero. Returns
  /// `Duration.zero` if the offer is already expired so the
  /// caller can branch without a separate "is expired" check.
  Duration get timeRemaining {
    final diff = endDate.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  factory PromoOffer.fromMap(Map<String, dynamic> map) {
    return PromoOffer(
      id: map['id'] as String,
      title: (map['title'] as String?)?.trim() ?? 'Sale',
      description: (map['description'] as String?)?.trim(),
      discountPercentage:
          (map['discount_percentage'] as num?)?.toInt() ?? 0,
      bannerImageUrl: (map['banner_image_url'] as String?)?.trim().isEmpty ??
              true
          ? null
          : (map['banner_image_url'] as String).trim(),
      endDate:
          DateTime.tryParse(map['end_date'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
      targetRoute: (map['target_route'] as String?)?.trim().isEmpty ?? true
          ? null
          : (map['target_route'] as String).trim(),
      promoCode: (map['promo_code'] as String?)?.trim().isEmpty ?? true
          ? null
          : (map['promo_code'] as String).trim(),
      isActive: map['is_active'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
      offerType: OfferType.fromDb(map['offer_type'] as String?),
      bankName: (map['bank_name'] as String?)?.trim().isEmpty ?? true
          ? null
          : (map['bank_name'] as String).trim(),
    );
  }
}

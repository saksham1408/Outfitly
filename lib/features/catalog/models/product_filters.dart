/// Sort options shown in the Sort bottom sheet.
enum SortOption {
  whatsNew('What\'s new'),
  priceHighToLow('Price - high to low'),
  popularity('Popularity'),
  discount('Discount'),
  priceLowToHigh('Price - low to high'),
  customerRating('Customer Rating');

  final String label;
  const SortOption(this.label);
}

/// Filter categories shown in the left pane of the Filter bottom sheet.
enum FilterCategory {
  quickFilters('Quick Filters'),
  size('Size'),
  color('Color'),
  fabric('Fabric'),
  priceRange('Price Range'),
  deliveryTime('Delivery Time');

  final String label;
  const FilterCategory(this.label);

  /// Options shown in the right pane when this category is selected.
  List<String> get options {
    switch (this) {
      case FilterCategory.quickFilters:
        return const [
          'Under ₹2,000',
          'Newly Added',
          'Bestseller',
          'Free Delivery',
        ];
      case FilterCategory.size:
        return const ['XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL'];
      case FilterCategory.color:
        return const [
          'Black',
          'White',
          'Blue',
          'Red',
          'Green',
          'Beige',
          'Brown',
          'Navy',
          'Maroon',
          'Gold',
        ];
      case FilterCategory.fabric:
        return const [
          'Cotton',
          'Linen',
          'Silk',
          'Wool',
          'Khadi',
          'Velvet',
          'Chambray',
        ];
      case FilterCategory.priceRange:
        return const [
          '₹0 – ₹2,000',
          '₹2,000 – ₹5,000',
          '₹5,000 – ₹10,000',
          '₹10,000 – ₹20,000',
          '₹20,000+',
        ];
      case FilterCategory.deliveryTime:
        return const ['3–5 days', '7–10 days', '10–14 days', '14+ days'];
    }
  }

  /// Single-select categories use radio tiles. Others are multi-select.
  bool get isSingleSelect =>
      this == FilterCategory.priceRange || this == FilterCategory.deliveryTime;
}

/// Aggregate filter state held by the catalog screen.
class ProductFilters {
  SortOption sort;
  Map<FilterCategory, Set<String>> selectedOptions;

  ProductFilters({
    this.sort = SortOption.whatsNew,
    Map<FilterCategory, Set<String>>? selectedOptions,
  }) : selectedOptions = selectedOptions ??
            {for (final c in FilterCategory.values) c: <String>{}};

  int get activeFilterCount =>
      selectedOptions.values.fold(0, (sum, s) => sum + s.length);

  bool get hasActiveFilters => activeFilterCount > 0;

  void clearAll() {
    for (final c in FilterCategory.values) {
      selectedOptions[c] = <String>{};
    }
  }

  ProductFilters copy() {
    return ProductFilters(
      sort: sort,
      selectedOptions: {
        for (final e in selectedOptions.entries) e.key: Set.of(e.value),
      },
    );
  }
}

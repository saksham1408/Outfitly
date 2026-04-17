import 'package:flutter/material.dart';

/// Category row shown exclusively at the top of the MEN tab.
class MenCategory {
  final String name;
  final IconData icon;

  const MenCategory({required this.name, required this.icon});
}

/// Exact order as specified in the design review.
const List<MenCategory> menCategories = [
  MenCategory(name: 'Ethnics', icon: Icons.dry_cleaning_rounded),
  MenCategory(name: 'Sherwanis', icon: Icons.accessibility_new_rounded),
  MenCategory(name: 'Blazers', icon: Icons.checkroom_rounded),
  MenCategory(name: 'Suits', icon: Icons.work_outline_rounded),
  MenCategory(name: 'Formal Shirts', icon: Icons.ios_share_rounded),
  MenCategory(name: 'Formal Pants', icon: Icons.swap_vert_rounded),
  MenCategory(name: 'Embroidery', icon: Icons.auto_awesome_rounded),
];

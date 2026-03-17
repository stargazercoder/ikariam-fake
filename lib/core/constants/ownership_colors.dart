import 'package:flutter/material.dart';

/// Centralized ownership color constants for city/map screens.
/// Single source of truth — import from here, never hardcode.
class OwnershipColors {
  OwnershipColors._();

  /// Player's own city — green.
  static const Color own = Color(0xFF43A047);   // Colors.green.shade600

  /// Enemy-owned city — red.
  static const Color enemy = Color(0xFFE53935); // Colors.red.shade600

  /// Empty/unoccupied slot — grey.
  static const Color empty = Color(0xFFBDBDBD); // Colors.grey.shade400
}

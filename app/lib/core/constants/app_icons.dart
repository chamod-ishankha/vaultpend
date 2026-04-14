import 'package:flutter/material.dart';

/// Centralized IconData catalog for the VaultSpend application.
class AppIcons {
  AppIcons._();

  // Navigation & Shell
  static const IconData expensesActive = Icons.payments;
  static const IconData expensesInactive = Icons.payments_outlined;
  static const IconData subscriptionsActive = Icons.subscriptions;
  static const IconData subscriptionsInactive = Icons.subscriptions_outlined;
  static const IconData insightsActive = Icons.query_stats;
  static const IconData insightsInactive = Icons.query_stats_outlined;

  static const IconData categories = Icons.category_outlined;
  static const IconData settings = Icons.settings_outlined;
  static const IconData syncStatus = Icons.sync_rounded;
  static const IconData syncCheck = Icons.check_circle_rounded;
  static const IconData userProfile = Icons.person_outline_rounded;
  static const IconData logout = Icons.logout;
  static const IconData login = Icons.login;

  // Actions
  static const IconData add = Icons.add_rounded;
  static const IconData edit = Icons.edit_rounded;
  static const IconData delete = Icons.delete_rounded;
  static const IconData check = Icons.check_rounded;
  static const IconData close = Icons.close_rounded;
  static const IconData error = Icons.error_outline_rounded;
  static const IconData share = Icons.ios_share_rounded;
  static const IconData menu = Icons.menu;
  static const IconData moreVert = Icons.more_vert_rounded;

  // Visual
  static const IconData visibilityOn = Icons.visibility_rounded;
  static const IconData visibilityOff = Icons.visibility_off_rounded;
  static const IconData analytics = Icons.auto_graph_rounded;
  static const IconData colorPalette = Icons.palette_rounded;
  static const IconData gridView = Icons.grid_view_rounded;
  static const IconData filePdf = Icons.picture_as_pdf_rounded;
  static const IconData fileCsv = Icons.table_chart_rounded;
}

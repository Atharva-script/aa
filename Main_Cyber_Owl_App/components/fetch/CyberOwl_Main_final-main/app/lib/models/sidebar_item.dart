import 'package:flutter/material.dart';

class SidebarItem {
  final IconData icon;
  final String title;
  final String route;
  final Color? color;

  const SidebarItem({
    required this.icon,
    required this.title,
    this.route = '',
    this.color,
  });
}

import 'package:flutter/material.dart';

import '../utils/severity_utils.dart';

class SeverityBadge extends StatelessWidget {
  const SeverityBadge({super.key, required this.severity});

  final String severity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _severityColor(severity),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        getSeverityDisplay(severity),
        style: TextStyle(
          color: _textColor(severity),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  static Color _severityColor(String value) {
    switch (value.toUpperCase()) {
      case 'RED':
        return Colors.red.shade50;
      case 'ORANGE':
        return Colors.orange.shade50;
      case 'YELLOW':
        return Colors.yellow.shade100;
      default:
        return Colors.green.shade50;
    }
  }

  static Color _textColor(String value) {
    switch (value.toUpperCase()) {
      case 'RED':
        return Colors.red.shade700;
      case 'ORANGE':
        return Colors.orange.shade800;
      case 'YELLOW':
        return Colors.yellow.shade900;
      default:
        return Colors.green.shade700;
    }
  }
}

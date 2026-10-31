import 'package:flutter/material.dart';

PopupMenuItem<String> appPopupMenuItem({
  required String value,
  required IconData icon,
  required String label,
  bool destructive = false,
}) {
  return PopupMenuItem<String>(
    value: value,
    child: Builder(
      builder: (context) {
        final color = destructive ? Theme.of(context).colorScheme.error : null;
        return Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: color)),
          ],
        );
      },
    ),
  );
}

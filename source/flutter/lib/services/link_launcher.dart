import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openExternalLink(BuildContext context, String value) async {
  final uri = Uri.tryParse(value.trim());
  final opened =
      uri != null &&
      uri.hasAuthority &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      await launchUrl(uri, mode: LaunchMode.externalApplication);

  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('无法打开这个链接')));
  }
}

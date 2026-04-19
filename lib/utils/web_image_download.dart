import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;

Future<void> downloadImageOnWeb(
  Uint8List bytes, {
  String fileName = 'mind_galaxy_star.png',
}) async {
  if (!kIsWeb) return;

  final blob = html.Blob([bytes], 'image/png');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';

  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}

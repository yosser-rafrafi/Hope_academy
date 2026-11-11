import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:share_plus/share_plus.dart';

/// One entry point for sharing text / images / PDFs / CSVs to any app that
/// appears in the system share sheet (Facebook, Instagram, WhatsApp, Mail,
/// Drive…). Uses the `share_plus` static API (v10.x).
class ShareService {
  ShareService._();

  static const String hashtag = '#HopeAcademyEgypt';

  static Future<void> shareText(String text, {String? subject}) {
    return Share.share(text, subject: subject);
  }

  static Future<void> shareBytes(
    Uint8List bytes, {
    required String fileName,
    required String mimeType,
    String? text,
    String? subject,
  }) {
    final file = XFile.fromData(bytes, mimeType: mimeType, name: fileName);
    return Share.shareXFiles(
      [file],
      subject: subject,
      text: text,
      fileNameOverrides: [fileName],
    );
  }

  static Future<void> shareFiles(List<XFile> files, {String? text}) {
    return Share.shareXFiles(files, text: text);
  }

  static Future<void> sharePng(Uint8List png,
          {required String name, String? text}) =>
      shareBytes(png, fileName: '$name.png', mimeType: 'image/png', text: text);

  static Future<void> sharePdf(Uint8List pdf,
          {required String name, String? text}) =>
      shareBytes(pdf,
          fileName: '$name.pdf', mimeType: 'application/pdf', text: text);

  static Future<void> shareCsv(String csv,
          {required String name, String? text}) =>
      shareBytes(Uint8List.fromList(utf8.encode('\uFEFF$csv')),
          fileName: '$name.csv', mimeType: 'text/csv', text: text);

  /// Renders the widget behind [key] (wrapped in a RepaintBoundary) to PNG.
  static Future<Uint8List> capture(GlobalKey key,
      {double pixelRatio = 3}) async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }
}

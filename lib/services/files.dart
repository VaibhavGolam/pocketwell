import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'app_lock.dart';

/// Saving a file out of the app (backup, CSV) and reading one back in.
class FileService {
  FileService._();

  /// Writes [content] to a temporary file and opens the phone's share sheet,
  /// where the person picks Drive, WhatsApp, Files and so on.
  static Future<void> shareText(
    BuildContext context, {
    required String fileName,
    required String content,
    required String mimeType,
    String? subject,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(content, flush: true);
    if (!context.mounted) return;

    // iPad needs to know where the share sheet should point.
    final box = context.findRenderObject() as RenderBox?;
    final origin = (box != null && box.hasSize)
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    AppLock.allowAwayFor(const Duration(minutes: 3));
    await Share.shareXFiles(
      [XFile(file.path, mimeType: mimeType)],
      subject: subject,
      sharePositionOrigin: origin,
    );
  }

  /// Lets the person pick a file and returns its text. Null if they backed
  /// out. Throws a [FormatException] if the file is not text.
  static Future<String?> pickText() async {
    AppLock.allowAwayFor(const Duration(minutes: 3));
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final bytes = result.files.single.bytes;
    if (bytes == null) return null;
    var text = utf8.decode(bytes);
    if (text.startsWith('﻿')) text = text.substring(1);
    return text;
  }
}

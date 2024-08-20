import 'dart:io';

import 'opensubtitles_hash.dart';

class VideoHasher {
  static Future<String> calculateHash(String filePath) async {
    String hash = await OpenSubtitlesHasher.computeFileHash(File(filePath));
    return hash;
  }
}

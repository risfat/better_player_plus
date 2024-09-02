import 'dart:convert';
import 'dart:io';
import 'video_hasher.dart';
import 'package:path/path.dart' as path;

class SubtitleDownloader {
  static final SubtitleDownloader _instance = SubtitleDownloader._internal();

  factory SubtitleDownloader() {
    return _instance;
  }

  SubtitleDownloader._internal();

  static const _apiBaseUrl = 'https://opensubtitles-api-wrapper.vercel.app';
  static const _apiSecretKey = '_X%aguSdC-V1JU!';

  /// Searches for subtitles based on the video name and movie hash.
  /// Returns a list of available subtitles.
  Future<List<Map<String, dynamic>>?> searchSubtitles(
      String videoPath, {
        String language = 'en',
        String orderBy = 'new_download_count',
        bool useHash = false
      }) async {
    String? movieHash;
    if (useHash) {
      movieHash = await VideoHasher.calculateHash(videoPath);
      print("=====================Movie Hash: $movieHash===========================");
    }

    final query = path.basenameWithoutExtension(videoPath);
    String url = '$_apiBaseUrl/search?query=$query&languages=$language&order_by=$orderBy';

    if (useHash && movieHash != null) {
      url += '&movieHash=$movieHash';
    }

    print("======================$url==========================");
    try {
      final request = await HttpClient().getUrl(Uri.parse(url));
      request.headers.set('x-api-key', _apiSecretKey);
      request.headers.set('Content-Type', 'application/json');

      final httpResponse = await request.close();
      if (httpResponse.statusCode == 200) {
        final content = await httpResponse.transform(utf8.decoder).join();
        final Map<String, dynamic> data = jsonDecode(content);
        final List subtitles = data['data'];
        if (subtitles.isNotEmpty) {
          return subtitles.cast<Map<String, dynamic>>();
        } else {
          print('No subtitles found for your query: $query');
        }
      } else {
        print('Failed to search subtitles: ${httpResponse.statusCode}');
        final errorContent = await httpResponse.transform(utf8.decoder).join();
        print('Error: $errorContent');
      }
    } catch (e) {
      print('Error during subtitle search: $e');
    }
    return null;
  }

  /// Downloads the subtitles based on the file ID.
  Future<File?> downloadSubtitles(int fileId, String savePath) async {
    final url = '$_apiBaseUrl/download?fileId=$fileId';

    try {
      final request = await HttpClient().getUrl(Uri.parse(url));
      request.headers.set('x-api-key', _apiSecretKey);
      request.headers.set('Content-Type', 'application/json');

      final httpResponse = await request.close();
      if (httpResponse.statusCode == 200) {
        final content = await httpResponse.transform(utf8.decoder).join();
        final Map<String, dynamic> data = jsonDecode(content);
        final downloadUrl = data['link'];

        print('Subtitle download URL: $downloadUrl');

        final downloadRequest = await HttpClient().getUrl(Uri.parse(downloadUrl));
        final downloadResponse = await downloadRequest.close();

        final file = File(savePath);
        await downloadResponse.pipe(file.openWrite());

        print('Subtitle downloaded successfully to $savePath');
        return file;
      } else {
        print('Failed to download subtitles: ${httpResponse.statusCode}');
        final errorContent = await httpResponse.transform(utf8.decoder).join();
        print('Error: $errorContent');
      }
    } catch (e) {
      print('Error during subtitle download: $e');
      rethrow;
    }
    return null;
  }
}

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

  static const _apiKey = 'OeQDlQbgsIXgS7acRceOG7ZDJRNntxO5';
  static const _userAgent = 'RxPlayer/1.0'; // Replace with your app name and version
  static const _username = 'risfat';
  static const _password = '/KDUtT6Hha,8+K@';

  String? _bearerToken;

  /// Logs in to the OpenSubtitles API and retrieves a bearer token.
  Future<void> _login() async {
    const url = 'https://api.opensubtitles.com/api/v1/login';
    final requestBody = jsonEncode({
      'username': _username,
      'password': _password,
    });

    try {
      final request = await HttpClient().postUrl(Uri.parse(url));
      request.headers.set('Api-Key', _apiKey);
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('User-Agent', '');
      request.headers.set('X-User-Agent', _userAgent);
      request.write(requestBody);

      final httpResponse = await request.close();
      if (httpResponse.statusCode == 200) {
        final content = await httpResponse.transform(utf8.decoder).join();
        final Map<String, dynamic> data = jsonDecode(content);
        _bearerToken = data['token'] as String?;
        print('Logged in successfully, token obtained.');
      } else {
        print('Login failed: ${httpResponse.statusCode}');
      }
    } catch (e) {
      print('Error during login: $e');
    }
  }

  /// Ensures the bearer token is available, logging in if necessary.
  Future<void> _ensureLoggedIn() async {
    if (_bearerToken == null) {
      await _login();
    }
  }

  /// Searches for subtitles based on the video name and movie hash.
  /// Returns a list of available subtitles.
  Future<List<Map<String, dynamic>>?> searchSubtitles(
      String videoPath, {
        String language = 'en',
        String orderBy = 'new_download_count',
        bool useHash = false
      }) async {
    // await _ensureLoggedIn();

    String? movieHash;
    if (useHash) {
      movieHash = await VideoHasher.calculateHash(videoPath);
      print("=====================Movie Hash: $movieHash===========================");
    }


    final query = path.basenameWithoutExtension(videoPath);
    final url =
        useHash ? 'https://api.opensubtitles.com/api/v1/subtitles?query=$query&languages=$language&order_by=$orderBy&moviehash=$movieHash' :
        'https://api.opensubtitles.com/api/v1/subtitles?query=$query&languages=$language&order_by=$orderBy';

    print("======================$url==========================");
    try {
      final request = await HttpClient().getUrl(Uri.parse(url));
      request.headers.set('Api-Key', _apiKey);
      request.headers.set('User-Agent', '');
      request.headers.set('X-User-Agent', _userAgent);
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
    await _ensureLoggedIn();

    const url = 'https://api.opensubtitles.com/api/v1/download';
    final requestBody = jsonEncode({'file_id': fileId});

    try {
      final request = await HttpClient().postUrl(Uri.parse(url));
      request.headers.set('Api-Key', _apiKey);
      request.headers.set('Authorization', 'Bearer $_bearerToken');
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Accept', 'application/json');
      request.headers.set('User-Agent', _userAgent);
      request.write(requestBody);

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
        if (httpResponse.statusCode == 401) {
          // Token might be invalid or expired, re-login and retry
          print('Token expired, retrying login...');
          await _login();
          return await downloadSubtitles(fileId, savePath);
        }
        final errorContent = await httpResponse.transform(utf8.decoder).join();
        print('Failed to download subtitles: ${httpResponse.statusCode}');
        print('Error: $errorContent');
      }
    } catch (e) {
      print('Error during subtitle download: $e');
    }
    return null;
  }
}

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:sylvakru/base/services/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:sylvakru/base/data/playlist.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';

StreamClient? streamClient;

abstract class StreamClient {
  /// Mutable: a server may be reachable at two addresses and the app switches
  /// to the other one when this one stops answering.
  String baseUrl;
  final String username;
  final String password;

  /// The same server's other address (public vs LAN), tried when a request
  /// fails because the current address is not reachable.
  String? alternativeBaseUrl;

  @protected
  late final Dio dio;

  StreamClient({
    required this.baseUrl,
    required this.username,
    required this.password,
  });

  @protected
  List<Map<String, dynamic>>? normalize(dynamic data) {
    if (data == null) {
      return null;
    }
    return (data as List).cast();
  }

  /// Address as the client's own requests should use it; clients that rewrite
  /// the stored address (Feiniu appends its API path) override this.
  String normalizeBaseUrl(String url) => url;

  /// Switches to the server's other address. False when there is none left.
  bool switchToAlternative() {
    final other = alternativeBaseUrl;
    if (other == null || other.isEmpty || other == baseUrl) {
      return false;
    }
    alternativeBaseUrl = baseUrl;
    baseUrl = other;
    dio.options.baseUrl = normalizeBaseUrl(other);
    return true;
  }

  static bool isNetworkFailure(Object error) {
    if (error is! DioException) {
      return false;
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      default:
        return false;
    }
  }

  /// Sends a GET request; when it fails because the server is unreachable, the
  /// request is retried once against the server's other address.
  @protected
  Future<Response<dynamic>> getWithFailover(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } catch (error) {
      if (!isNetworkFailure(error) || !switchToAlternative()) {
        rethrow;
      }
      logger.output('[${runtimeType}] switched to $baseUrl');
      return await dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    }
  }

  Future<bool> ping();

  Future<int> getSongCount() async {
    return 0;
  }

  Future<List<MyAudioMetadata>?> getSongs(int size, int offset);

  Future<List<MyAudioMetadata>?> getStarredSongs();

  Future<bool> updateStarredSongs(List<String> songIds);

  Future<List<Playlist>?> getPlaylists();

  Future<String?> createPlaylist(String name);

  Future<bool> deletePlaylist(String playlistId);

  Future<List<MyAudioMetadata>?> getPlaylistSongs(String playlistId);

  Future<bool> updatePlaylistSongs(String playlistId, List<String> songIds);

  String getStreamUrl(String id);

  Map<String, String>? get headers => null;

  Future<Uint8List?> getPictureBytes(String songId);

  /// A URL anyone on the network can fetch to get the cover art, or null when
  /// the source cannot expose one (local files, header-authenticated servers).
  /// System media UIs and car head units read this from the media session
  /// metadata, so it must not require request headers.
  String? getPictureUrl(String songId) => null;

  Future<String> getLyricsById(String songId);

  Future<bool> downloadSong(String songId, String savePath);

  Future<bool> scrobble(String songId);
}

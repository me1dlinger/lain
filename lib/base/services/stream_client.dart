import 'dart:async';

import 'package:dio/dio.dart';
import 'package:lain/base/services/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:lain/base/data/playlist.dart';
import 'package:lain/base/my_audio_metadata.dart';

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

  /// Called when the client moves to the alternative address, so the server
  /// record and the settings page can name the address actually in use.
  void Function(String url)? onAddressChanged;

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
    final normalized = normalizeBaseUrl(other);
    alternativeBaseUrl = baseUrl;
    baseUrl = normalized;
    dio.options.baseUrl = normalized;
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

  /// Sends a GET request. When the current address fails, the same request is
  /// tried against the server's other address and the app only moves there if
  /// *that* request actually succeeds.
  ///
  /// Switching on the bare failure - as this used to - meant one flaky timeout
  /// against a perfectly good public address moved the whole app back to the
  /// LAN address, where the next request failed and moved it again.
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
      final other = alternativeBaseUrl;
      if (!isNetworkFailure(error) ||
          other == null ||
          other.isEmpty ||
          other == baseUrl) {
        rethrow;
      }

      final otherUrl = normalizeBaseUrl(other);
      final probe = Dio(
        BaseOptions(
          baseUrl: otherUrl,
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
        ),
      );
      final Response<dynamic> response;
      try {
        response = await probe.get(
          path,
          queryParameters: queryParameters,
          options: options,
        );
      } catch (_) {
        // The other address does not answer either: this is not an address
        // problem, so keep the current one and let the caller see the error.
        rethrow;
      }

      alternativeBaseUrl = baseUrl;
      baseUrl = otherUrl;
      dio.options.baseUrl = otherUrl;
      onAddressChanged?.call(otherUrl);
      logger.output('[${runtimeType}] switched to $baseUrl');
      return response;
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

  /// Fetches the song as the server stores it, for the user to keep - unlike
  /// [downloadSong], which is what the offline cache holds and may be a
  /// transcoded copy. Sources without a "give me the original" endpoint inherit
  /// this.
  Future<bool> downloadOriginal(String songId, String savePath) =>
      downloadSong(songId, savePath);

  Future<bool> scrobble(String songId);

  /// Whether this source can star a whole album or artist (as opposed to single
  /// songs only). Local libraries answer true through their own store.
  bool get supportsEntityFavorites => false;

  /// Stars or unstars an album or an artist.
  Future<bool> setStarred(String id, bool starred) async => false;

  /// Ids of the starred albums, or of the starred artists, each with the time it
/// was starred (null when the server does not report one).
  Future<Map<String, DateTime?>> getStarredIds({required bool isArtist}) async =>
      {};

  /// The album's description/notes, or null when the source has none.
  Future<String?> getAlbumNotes(String albumId) async => null;

  /// The album's description from the source's own API, for a server that keeps
  /// one its Subsonic endpoint does not expose. Null when there is none.
  Future<String?> getAlbumDescription(String albumId) async => null;

  /// Biography and image URL for an artist, or null when the source has none.
  Future<({String? biography, String? imageUrl})?> getArtistInfo(
    String artistId,
  ) async => null;

  /// An artist's image URL from the source's own API, for a server that reports
/// one its Subsonic endpoint omits. Null when there is none.
  Future<String?> getArtistImageUrl(String artistId) async => null;

  /// Every artist with its id, whether the server has an image for it, and its
  /// biography, from the source's own list API. Null when unsupported.
  Future<
    List<
      ({
        String id,
        String name,
        bool hasImage,
        String? biography,
        String? imageUrl,
      })
    >?
  >
  getArtistSummaries() async => null;
}

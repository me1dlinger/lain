import 'package:flutter_test/flutter_test.dart';
import 'package:lain/base/services/webdav_client.dart';

void main() {
  group('WebDAV address parsing', () {
    test('an encoded non-ASCII base path is decoded, the origin is kept', () {
      final client = WebDavClient(
        baseUrl:
            'http://102419.xyz:5005/meidlinger%20%E5%85%B1%E4%BA%AB%E7%BB%99%E6%88%91/Music/computer',
        username: 'u',
        password: 'p',
      );
      expect(client.cleanBaseUrl, 'http://102419.xyz:5005');
      expect(client.initialPath, '/meidlinger 共享给我/Music/computer');
    });

    test('a root address leaves no base path', () {
      final withSlash = WebDavClient(
        baseUrl: 'http://102419.xyz:5005/',
        username: 'u',
        password: 'p',
      );
      final withoutSlash = WebDavClient(
        baseUrl: 'http://102419.xyz:5005',
        username: 'u',
        password: 'p',
      );
      expect(withSlash.cleanBaseUrl, 'http://102419.xyz:5005');
      expect(withSlash.initialPath, '');
      expect(withoutSlash.cleanBaseUrl, 'http://102419.xyz:5005');
      expect(withoutSlash.initialPath, '');
    });

    test('relativePath strips the configured base', () {
      final client = WebDavClient(
        baseUrl: 'http://102419.xyz:5005/music',
        username: 'u',
        password: 'p',
      );
      expect(client.relativePath('/music/Artist/Album'), '/Artist/Album');
      expect(client.relativePath('/elsewhere/Album'), '/elsewhere/Album');
    });
  });

  group('remote URL encoding', () {
    test('hash, question mark and spaces in a path are encoded', () {
      expect(
        WebDavClient.encodeRemoteUrl(
          'http://102419.xyz:5005/a b/#1/What? .mp3',
        ),
        'http://102419.xyz:5005/a%20b/%231/What%3F%20.mp3',
      );
    });
  });
}

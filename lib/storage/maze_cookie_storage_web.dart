// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

class MazeCookieStorage {
  static const _cookieName = 'trying_flutter_maze';
  static const _maxAgeSeconds = 60 * 60 * 24 * 365;

  String? load() {
    final cookies = html.document.cookie?.split('; ') ?? const [];

    for (final cookie in cookies) {
      final separatorIndex = cookie.indexOf('=');
      if (separatorIndex == -1) continue;

      final name = Uri.decodeComponent(cookie.substring(0, separatorIndex));
      if (name != _cookieName) continue;

      return Uri.decodeComponent(cookie.substring(separatorIndex + 1));
    }

    return null;
  }

  void save(String value) {
    html.document.cookie =
        '${Uri.encodeComponent(_cookieName)}=${Uri.encodeComponent(value)}; '
        'max-age=$_maxAgeSeconds; path=/; SameSite=Lax';
  }

  void clear() {
    html.document.cookie =
        '${Uri.encodeComponent(_cookieName)}=; max-age=0; path=/; SameSite=Lax';
  }
}

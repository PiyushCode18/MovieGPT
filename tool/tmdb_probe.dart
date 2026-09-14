// Dart-stack TMDB probe: tests BOTH TMDB API hostnames with the real key.
// SECURITY: never prints the key - only status, counts, and titles.
import 'dart:convert';
import 'dart:io';

Map<String, String> loadEnvFile(String path) {
  final out = <String, String>{};
  for (final rawLine in File(path).readAsStringSync().split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final idx = line.indexOf('=');
    if (idx <= 0) continue;
    out[line.substring(0, idx).trim()] = line.substring(idx + 1).trim();
  }
  return out;
}

Future<void> probeHost(HttpClient client, String host, String key) async {
  stdout.writeln('--- $host ---');
  try {
    final req = await client.getUrl(Uri.parse(
        'https://$host/3/trending/movie/day?api_key=$key&language=en-US'));
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    stdout.writeln('HTTP ${res.statusCode}');
    if (res.statusCode == 200) {
      final results =
          ((jsonDecode(body) as Map)['results'] as List? ?? const []);
      stdout.writeln('results count: ${results.length}');
      if (results.isNotEmpty) {
        stdout.writeln('first title: ${(results.first as Map)['title']}');
      }
    } else {
      final data = jsonDecode(body) as Map;
      stdout.writeln('status_code: ${data['status_code']}');
      stdout.writeln('status_message: ${data['status_message']}');
    }
  } catch (e) {
    stdout.writeln('error: ${e.runtimeType}: $e');
  }
}

Future<void> main() async {
  final key = loadEnvFile('.env')['TMDB_API_KEY'] ?? '';
  stdout.writeln('TMDB configured: ${key.isNotEmpty}');
  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 15);
  await probeHost(client, 'api.themoviedb.org', key);
  await probeHost(client, 'api.tmdb.org', key);
  client.close();
}

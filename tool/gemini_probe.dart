// Live service probe for MovieGPT diagnostics.
// SECURITY: reads .env locally, NEVER prints secret values - only booleans,
// lengths, status codes and key-free provider error messages.
import 'dart:convert';
import 'dart:io';

Map<String, String> loadEnvFile(String path) {
  final out = <String, String>{};
  for (final rawLine in File(path).readAsStringSync().split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final idx = line.indexOf('=');
    if (idx <= 0) continue;
    var value = line.substring(idx + 1).trim();
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      value = value.substring(1, value.length - 1);
    }
    out[line.substring(0, idx).trim()] = value;
  }
  return out;
}

void printErrBody(String body) {
  try {
    final err = (jsonDecode(body) as Map)['error'];
    if (err is Map) {
      stdout.writeln('error: ${err['code']} ${err['status']}');
      stdout.writeln('message: ${err['message']}');
    } else {
      stdout.writeln('unrecognized error body (length ${body.length})');
    }
  } catch (_) {
    stdout.writeln('non-JSON error body (length ${body.length})');
  }
}

Future<void> main() async {
  final env = loadEnvFile('.env');
  final tmdbKey = env['TMDB_API_KEY'] ?? '';
  final geminiKey = env['GEMINI_API_KEY'] ?? '';
  final geminiModel = (env['GEMINI_MODEL'] ?? '').trim();
  final provider = (env['AI_PROVIDER'] ?? '').trim();
  stdout.writeln('--- DIAGNOSTIC SUMMARY (no secrets) ---');
  stdout.writeln('TMDB configured: ${tmdbKey.isNotEmpty}');
  stdout.writeln('Gemini configured: ${geminiKey.isNotEmpty}');
  stdout.writeln('OpenAI configured: ${(env['OPENAI_API_KEY'] ?? '').isNotEmpty}');
  stdout.writeln('AI provider: ${provider.isEmpty ? 'auto' : provider}');
  stdout.writeln('GEMINI_MODEL: ${geminiModel.isEmpty ? '<unset>' : geminiModel}');
  stdout.writeln('Gemini key length: ${geminiKey.length} chars');

  // ---- TMDB probe ----
  stdout.writeln('\n--- TMDB probe: /trending/movie/day ---');
  try {
    final client = HttpClient();
    final req = await client.getUrl(Uri.parse(
      'https://api.themoviedb.org/3/trending/movie/day?api_key=$tmdbKey'));
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
    client.close();
  } catch (e) {
    stdout.writeln('TMDB network error: $e');
  }

  // ---- Gemini probe ----
  stdout.writeln(
      '\n--- Gemini probe: models/$geminiModel:generateContent ---');
  HttpClient? client;
  try {
    client = HttpClient();
    final req = await client.postUrl(Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/'
        '$geminiModel:generateContent'));
    req.headers.set('Content-Type', 'application/json');
    req.headers.set('x-goog-api-key', geminiKey);
    final payload = utf8.encode(jsonEncode({
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': 'Reply with exactly: OK'},
          ],
        },
      ],
      'generationConfig': {'maxOutputTokens': 2048},
    }));
    req.add(payload);
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    stdout.writeln('HTTP ${res.statusCode}');
    if (res.statusCode == 200) {
      final data = jsonDecode(body) as Map;
      stdout.writeln('model echoed by API: ${data['model']}');
      final candidates = (data['candidates'] as List? ?? const []);
      if (candidates.isNotEmpty) {
        final cand = candidates.first as Map;
        final parts =
            (((cand['content'] as Map?)?['parts']) as List? ?? const []);
        var text = '';
        for (final p in parts) {
          if (p is Map && p['text'] is String) text += p['text'] as String;
        }
        stdout.writeln('response text: ${text.trim()}');
        stdout.writeln('finishReason: ${cand['finishReason']}');
      } else {
        stdout.writeln('no candidates. promptFeedback: ${data['promptFeedback']}');
      }
    } else {
      printErrBody(body);
      if (res.statusCode == 404 || res.statusCode == 400) {
        stdout.writeln('\n--- Gemini ListModels (gemini names only) ---');
        final req2 = await client.getUrl(
            Uri.parse('https://generativelanguage.googleapis.com/v1beta/models'));
        req2.headers.set('x-goog-api-key', geminiKey);
        final res2 = await req2.close();
        final body2 = await res2.transform(utf8.decoder).join();
        stdout.writeln('ListModels HTTP ${res2.statusCode}');
        if (res2.statusCode == 200) {
          for (final m in ((jsonDecode(body2) as Map)['models'] as List? ?? const [])) {
            if (m is Map && m['name'] is String && (m['name'] as String).contains('gemini')) {
              final ok = m['supportedGenerationMethods'] is List &&
                  (m['supportedGenerationMethods'] as List)
                      .contains('generateContent');
              stdout.writeln('${m['name']} (generateContent: $ok)');
            }
          }
        } else {
          printErrBody(body2);
        }
      }
    }
  } catch (e) {
    stdout.writeln('Gemini network error: $e');
  } finally {
    client?.close();
  }
}

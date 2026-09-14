// Downloads the example invoices OpenPeppol publishes with its rules.
//
// They come from https://github.com/OpenPEPPOL/peppol-bis-invoice-3, which
// carries no licence, so they are read by the test suite and never
// redistributed: they land in a directory git ignores.
//
// Usage:
//   dart run tool/fetch_examples.dart
import 'dart:convert';
import 'dart:io';

const String _listing =
    'https://api.github.com/repos/OpenPEPPOL/peppol-bis-invoice-3/'
    'contents/rules/examples';

const String _directory = 'examples_from_peppol';

Future<void> main() async {
  final client = HttpClient();
  try {
    final entries = await _json(client, _listing);
    Directory(_directory).createSync(recursive: true);
    var taken = 0;
    for (final entry in entries) {
      final name = entry['name'] as String;
      if (!name.toLowerCase().endsWith('.xml')) continue;
      final url = entry['download_url'] as String;
      File('$_directory/$name').writeAsStringSync(await _text(client, url));
      taken++;
    }
    stdout.writeln('$taken examples in $_directory');
  } finally {
    client.close();
  }
}

Future<List<Map<String, dynamic>>> _json(HttpClient client, String url) async {
  final body = await _text(client, url);
  return (jsonDecode(body) as List).cast<Map<String, dynamic>>();
}

Future<String> _text(HttpClient client, String url) async {
  final request = await client.getUrl(Uri.parse(url));
  request.headers.set('User-Agent', 'en16931_peppol');
  final token = Platform.environment['GITHUB_TOKEN'];
  if (token != null && token.isNotEmpty) {
    request.headers.set('Authorization', 'Bearer $token');
  }
  final response = await request.close();
  if (response.statusCode != 200) {
    throw HttpException('${response.statusCode} for $url');
  }
  return await response.transform(utf8.decoder).join();
}

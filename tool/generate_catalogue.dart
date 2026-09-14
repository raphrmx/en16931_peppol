// Reads the Peppol BIS Billing rule artefacts and writes the rule catalogue.
//
// The artefacts are published by OpenPeppol at
// https://github.com/OpenPEPPOL/peppol-bis-invoice-3. That repository carries
// no licence, so nothing of it is reproduced here: what is taken is which
// rules exist, what each is called, how severe it is, and which business
// terms it bears on. Those are facts. The meaning of every rule is
// implemented by hand against the semantic model, in this package's own
// words.
//
// Usage:
//   dart run tool/generate_catalogue.dart --fetch
//   dart run tool/generate_catalogue.dart [--dump <family>]
import 'dart:io';

import 'package:xml/xml.dart';

/// The release the artefacts are read from.
///
/// A tag rather than a branch, so that generating the catalogue twice gives
/// the same catalogue twice. Peppol revises its rules twice a year, and
/// reading from a moving branch leaves the package saying which rules it
/// covers without being able to say against what.
///
/// Raising this is a deliberate act: bump it, regenerate, and read what the
/// diff says before committing it.
const String artefactRelease = 'v3.0.20';

const String _base =
    'https://raw.githubusercontent.com/OpenPEPPOL/peppol-bis-invoice-3/'
    '$artefactRelease/rules/sch';

const Map<String, String> _sources = {
  'artefacts/peppol-ubl.sch': '$_base/PEPPOL-EN16931-UBL.sch',
  'artefacts/peppol-cii.sch': '$_base/PEPPOL-EN16931-CII.sch',
};

const String _output = 'lib/src/catalogue.g.dart';

/// A rule as the artefacts describe it.
class _Rule {
  _Rule(this.id, this.severity, this.terms);

  final String id;
  final String severity;
  final List<String> terms;
  final Set<String> syntaxes = {};
}

Future<void> main(List<String> arguments) async {
  if (arguments.contains('--fetch')) {
    for (final entry in _sources.entries) {
      await _fetch(entry.value, entry.key);
    }
  }

  final files = {
    'UBL': File('artefacts/peppol-ubl.sch'),
    'CII': File('artefacts/peppol-cii.sch'),
  };
  for (final file in files.values) {
    if (file.existsSync()) continue;
    stderr.writeln('Missing ${file.path}. Run with --fetch.');
    exitCode = 1;
    return;
  }

  final dump = arguments.indexOf('--dump');
  if (dump != -1 && dump + 1 < arguments.length) {
    _dump(files['UBL']!, arguments[dump + 1]);
    return;
  }

  final rules = <String, _Rule>{};
  String? version;
  for (final entry in files.entries) {
    final source = entry.value.readAsStringSync();
    version ??= _version(source);
    for (final rule in _read(source)) {
      final known = rules.putIfAbsent(rule.id, () => rule);
      known.syntaxes.add(entry.key);
      if (known.terms.isEmpty && rule.terms.isNotEmpty) {
        known.terms.addAll(rule.terms);
      }
    }
  }

  final catalogue = rules.values.toList()..sort((a, b) => a.id.compareTo(b.id));
  final lists = _lists(files['UBL']!.readAsStringSync());
  File(_output).writeAsStringSync(_emit(catalogue, version, lists));

  final names = lists.keys.toList()..sort();
  for (final name in names) {
    stdout.writeln('  $name: ${lists[name]!.length} codes');
  }
  stdout.writeln('${catalogue.length} rules written to $_output');
  stdout.writeln('  artefacts ${version ?? 'of unknown version'}');
  final counts = <String, int>{};
  for (final rule in catalogue) {
    counts[_family(rule.id)] = (counts[_family(rule.id)] ?? 0) + 1;
  }
  final families = counts.keys.toList()..sort();
  for (final family in families) {
    stdout.writeln('  $family: ${counts[family]}');
  }
  final oneSided = catalogue.where((r) => r.syntaxes.length == 1).toList();
  stdout.writeln('  ${oneSided.length} bound to one syntax');
}

/// Prints what the artefacts say about one family, to read while writing it.
void _dump(File file, String family) {
  final document = XmlDocument.parse(file.readAsStringSync());
  final seen = <String>{};
  for (final assertion in document.findAllElements('assert')) {
    final id = assertion.getAttribute('id');
    if (id == null || !id.startsWith(family)) continue;
    if (!seen.add(id)) continue;
    stdout.writeln(
      '$id [${assertion.getAttribute('flag')}] '
      '${assertion.innerText.trim()}',
    );
  }
  stdout.writeln('${seen.length} rules in $family');
}

Future<void> _fetch(String url, String target) async {
  Directory('artefacts').createSync(recursive: true);
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    if (response.statusCode != 200) {
      throw HttpException('${response.statusCode} for $url');
    }
    await response.pipe(File(target).openWrite());
    stdout.writeln('Fetched $target');
  } finally {
    client.close();
  }
}

/// The release the artefacts announce in their leading comment.
String? _version(String source) {
  final match = RegExp(
    r'Last update:\s*(\d{4}) (\w+) release ([0-9.]+)',
  ).firstMatch(source);
  if (match == null) return null;
  return '${match.group(3)}, ${match.group(2)} ${match.group(1)}';
}

/// Every rule one artefact file asserts.
Iterable<_Rule> _read(String source) sync* {
  final document = XmlDocument.parse(source);
  final seen = <String>{};
  for (final assertion in document.findAllElements('assert')) {
    final id = assertion.getAttribute('id');
    if (id == null || !id.startsWith('PEPPOL')) continue;
    if (!seen.add(id)) continue;
    final severity = assertion.getAttribute('flag') == 'warning'
        ? 'warning'
        : 'fatal';
    yield _Rule(id, severity, _terms(assertion.innerText));
  }
}

/// The business terms a rule bears on, read out of the message.
List<String> _terms(String message) {
  final found = <String>[];
  final pattern = RegExp(r'\b(?:BT|BG)-\d+(?:-\d+)?\b');
  for (final match in pattern.allMatches(message)) {
    final term = match.group(0)!;
    if (!found.contains(term)) found.add(term);
  }
  return found;
}

String _family(String id) {
  final match = RegExp('^(PEPPOL-[A-Z0-9]+-[A-Z]+)').firstMatch(id);
  return match?.group(1) ?? id;
}

String _emit(
  List<_Rule> rules,
  String? version,
  Map<String, Set<String>> lists,
) {
  final buffer = StringBuffer()
    ..writeln('// GENERATED by tool/generate_catalogue.dart. Do not edit.')
    ..writeln('//')
    ..writeln('// Read from the Peppol BIS Billing rule artefacts, release')
    ..writeln('// ${version ?? 'unknown'}. The artefacts carry no licence and')
    ..writeln('// none of their content is reproduced here: what is taken is')
    ..writeln('// which rules exist, how severe each is, and which business')
    ..writeln('// terms it bears on.')
    ..writeln()
    ..writeln("import 'package:en16931/en16931.dart';")
    ..writeln()
    ..writeln('/// Every rule Peppol BIS Billing 3.0 adds to EN 16931.')
    ..writeln('///')
    ..writeln('/// The list is read from the published artefacts, so it is')
    ..writeln('/// complete by construction rather than by memory.')
    ..writeln('const List<RuleDescriptor> peppolCatalogue = [');
  for (final rule in rules) {
    final terms = rule.terms.map((term) => "'$term'").join(', ');
    buffer
      ..writeln('  RuleDescriptor(')
      ..writeln("    id: '${rule.id}',")
      ..writeln('    family: RuleFamily.profile,')
      ..writeln('    severity: RuleSeverity.${rule.severity},')
      ..writeln('    terms: [$terms],')
      ..writeln('  ),');
  }
  buffer.writeln('];');
  final names = lists.keys.toList()..sort();
  for (final name in names) {
    final codes = lists[name]!.toList()..sort();
    buffer
      ..writeln()
      ..writeln('/// A code list Peppol narrows or points at.')
      ..writeln('///')
      ..writeln('/// ${codes.length} codes.')
      ..writeln('const Set<String> $name = {');
    for (final code in codes) {
      buffer.writeln("  '$code',");
    }
    buffer.writeln('};');
  }
  return buffer.toString();
}

/// What this package calls each code list the artefacts hold in a variable.
///
/// The lists themselves are ISO, UNTDID and the Peppol electronic address
/// list. What Peppol adds is the narrowing: its electronic address list is
/// shorter than the one the standard allows, and that difference is the whole
/// point of a profile.
const Map<String, String> _listNames = {
  'MIMECODE': 'peppolMimeTypes',
  'UNCL2005': 'peppolPeriodCodes',
  'UNCL5189': 'peppolAllowanceReasons',
  'UNCL7161': 'peppolChargeReasons',
  'UNCL5305': 'peppolVatCategories',
  'ISO4217': 'peppolCurrencies',
  'ISO3166': 'peppolCountries',
  'eaid': 'peppolElectronicAddressSchemes',
  'greekDocumentType': 'greekDocumentTypes',
};

/// The code lists the artefacts hold in their Schematron variables.
Map<String, Set<String>> _lists(String source) {
  final lists = <String, Set<String>>{};
  final pattern = RegExp(
    r"""<let name="([A-Za-z0-9_]+)" value="tokenize\('([^']*)'""",
  );
  for (final match in pattern.allMatches(source)) {
    final name = _listNames[match.group(1)];
    if (name == null) continue;
    final codes = match
        .group(2)!
        .trim()
        .split(RegExp(r'\s+'))
        .where((code) => code.isNotEmpty)
        .toSet();
    if (codes.isEmpty) continue;
    lists[name] = codes;
  }
  return lists;
}

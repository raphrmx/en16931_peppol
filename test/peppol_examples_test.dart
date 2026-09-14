import 'dart:io';

import 'package:en16931/en16931.dart';
import 'package:en16931_peppol/en16931_peppol.dart';
import 'package:en16931_ubl/en16931_ubl.dart';
import 'package:test/test.dart';

/// The example invoices OpenPeppol publishes beside its rules.
///
/// They are not part of this repository. Run
/// `dart run tool/fetch_examples.dart` to pull them in, and these tests wake
/// up. Checking our own invoices proves the rules do what this package thinks
/// they do; checking these proves they do what Peppol thinks they do.
const String _directory = 'examples_from_peppol';

void main() {
  final directory = Directory(_directory);
  if (!directory.existsSync()) {
    test('the published examples', () {}, skip: 'Run tool/fetch_examples.dart');
    return;
  }

  final files = directory.listSync().whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('there are examples to check', () {
    expect(files, isNotEmpty);
  });

  for (final file in files) {
    final name = file.uri.pathSegments.last;

    group(name, () {
      late Invoice invoice;

      setUp(() {
        invoice = readUbl(file.readAsStringSync());
      });

      test('claims the profile', () {
        expect(invoice.specificationIdentifier, peppolSpecification);
      });

      test('breaks no rule of Peppol', () {
        // These are the documents OpenPeppol publishes as examples of its own
        // profile. One of them reporting a violation means this package reads
        // or checks something wrong, not that the example is wrong.
        expect(
          validatePeppol(invoice).map((violation) => violation.toString()),
          isEmpty,
        );
      });
    });
  }
}

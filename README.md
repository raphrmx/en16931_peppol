<a alt="ComApps Logo" href="https://comapps.be" target="_blank" rel="noreferrer"><img src="https://www.comapps.be/wp-content/uploads/2026/09/CompleteLogoHorizontalMini.png" style="margin: 15px"></a>

# EN 16931 Peppol BIS

[![Build](https://img.shields.io/github/actions/workflow/status/raphrmx/en16931_peppol/ci.yml?branch=main&label=build)](https://github.com/raphrmx/en16931_peppol/actions/workflows/ci.yml)
[![Pub Version](https://img.shields.io/pub/v/en16931_peppol?color=blue)](https://pub.dev/packages/en16931_peppol)
[![Maintainer](https://img.shields.io/badge/Maintainer-Raphael_Vrient-purple)](https://pub.dev/publishers/comapps.be/packages)
[![License](https://img.shields.io/badge/Licence-MIT-blue)](/LICENSE)
![Maintenance](https://img.shields.io/badge/Maintained-yes-success)

Peppol BIS Billing 3.0: the 59 rules the network adds to EN 16931, and the
identifiers an invoice is claimed under.

An invoice can satisfy the standard and still be refused by Peppol. This says
so before it is sent.

## Install

```yaml
dependencies:
  en16931: ^0.1.0
  en16931_peppol: ^0.1.0
```

## Check an invoice

Claim the profile on the invoice, then check it. The standard and the profile
are checked together.

```dart
import 'package:en16931/en16931.dart';
import 'package:en16931_peppol/en16931_peppol.dart';

final invoice = Invoice.fromLines(
  number: '2026-0042',
  issueDate: DateTime(2026, 9, 13),
  specificationIdentifier: peppolSpecification,
  businessProcess: peppolBillingProcess,
  buyerReference: 'PO-77812',
  seller: const Seller(
    name: 'COMAPPS SRL',
    vatIdentifier: 'BE0123456789',
    electronicAddress: Identifier('0123456749', scheme: '0208'),
    address: Address(city: 'Bruxelles', postalCode: '1000', country: 'BE'),
  ),
  buyer: const Buyer(
    name: 'Client SA',
    electronicAddress: Identifier('0987654394', scheme: '0208'),
    address: Address(city: 'Namur', postalCode: '5000', country: 'BE'),
  ),
  lines: [...],
);

for (final violation in validatePeppol(invoice)) {
  print(violation);
}
```

## What Peppol adds

Three things an invoice that passes EN 16931 still gets refused for.

**An electronic address on both sides.** BT-34 and BT-49 are optional in the
standard and required here, because they are how the network delivers.

**A shorter list of address schemes.** Peppol carries 94 of the schemes the
standard allows, so a scheme that is perfectly valid under EN 16931 can still
be refused.

**A national identifier that is really shaped that way.** A Belgian
enterprise number under scheme 0208 has to pass the modulo 97 check, a GLN its
GS1 check digit, an Australian Business Number its modulus 89. A receiver
looks its supplier up by that number, and a mistyped one finds nobody.

```dart
isBelgianEnterprise('0123456749'); // true
isBelgianEnterprise('0123456789'); // false
```

## Worth knowing up front

Of the 59 rules, 48 are checked here, 6 cannot be broken by an invoice built
with this model, and 5 are about how the XML is put together rather than what
the invoice says. Those five belong to a syntax package, and
`peppolForTheSyntax` names them with what they ask.

The rule catalogue is read from the artefacts OpenPeppol publishes, so it is
complete by construction. A test fails when a rule has no answer.

## License

MIT.

// ignore_for_file: avoid_print

import 'package:en16931/en16931.dart';
import 'package:en16931_peppol/en16931_peppol.dart';

/// Builds an invoice claimed under Peppol and checks it against the standard
/// and the profile at once.
void main() {
  final invoice = Invoice.fromLines(
    number: '2026-0042',
    issueDate: DateTime(2026, 9, 13),
    dueDate: DateTime(2026, 10, 13),
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
    lines: [
      InvoiceLine.of(
        id: '1',
        item: const Item(name: 'Consulting'),
        quantity: 8,
        unitPrice: 150.00,
        vatRate: 21,
        unit: UnitCode.hour,
      ),
    ],
  );

  final violations = validatePeppol(invoice);
  print(violations.isEmpty ? 'ready for the network' : 'not yet:');
  for (final violation in violations) {
    print('  $violation');
  }
}

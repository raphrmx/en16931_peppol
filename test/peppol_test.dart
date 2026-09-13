import 'package:decimal/decimal.dart';
import 'package:en16931/en16931.dart';
import 'package:en16931_peppol/en16931_peppol.dart';
import 'package:test/test.dart';

Decimal _d(String value) => Decimal.parse(value);

const Seller _seller = Seller(
  name: 'COMAPPS SRL',
  vatIdentifier: 'BE0123456789',
  electronicAddress: Identifier('0123456749', scheme: '0208'),
  address: Address(city: 'Bruxelles', postalCode: '1000', country: 'BE'),
);

const Buyer _buyer = Buyer(
  name: 'Client SA',
  electronicAddress: Identifier('0987654394', scheme: '0208'),
  address: Address(city: 'Namur', postalCode: '5000', country: 'BE'),
);

/// An invoice ready for the network, so a test can break one thing at a time.
Invoice _peppol({
  Seller? seller,
  Buyer? buyer,
  String? specificationIdentifier = peppolSpecification,
  String? businessProcess = peppolBillingProcess,
  String? buyerReference = 'PO-77812',
  String? vatAccountingCurrency,
  InvoiceTypeCode? typeCode,
  List<InvoiceNote> notes = const [],
  List<InvoiceLine>? lines,
  List<VatBreakdown>? vatBreakdown,
  List<DocumentAllowanceCharge> allowancesAndCharges = const [],
  DatePeriod? invoicingPeriod,
  PaymentInstructions? paymentInstructions,
  List<SupportingDocument> supportingDocuments = const [],
}) {
  final invoice = Invoice.fromLines(
    number: '2026-0042',
    issueDate: DateTime(2026, 9, 13),
    typeCode: typeCode ?? InvoiceTypeCode.commercialInvoice,
    specificationIdentifier: specificationIdentifier,
    businessProcess: businessProcess,
    buyerReference: buyerReference,
    seller: seller ?? _seller,
    buyer: buyer ?? _buyer,
    allowancesAndCharges: allowancesAndCharges,
    invoicingPeriod: invoicingPeriod,
    paymentInstructions: paymentInstructions,
    supportingDocuments: supportingDocuments,
    notes: notes,
    lines: lines ??
        [
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
  if (vatBreakdown == null && vatAccountingCurrency == null) return invoice;

  // Two rules need a breakdown or a currency the builder would not produce,
  // so those tests state the invoice rather than deriving it.
  return Invoice(
    number: invoice.number,
    issueDate: invoice.issueDate,
    typeCode: invoice.typeCode,
    currency: invoice.currency,
    specificationIdentifier: invoice.specificationIdentifier,
    businessProcess: invoice.businessProcess,
    vatAccountingCurrency: vatAccountingCurrency,
    buyerReference: invoice.buyerReference,
    seller: invoice.seller,
    buyer: invoice.buyer,
    lines: invoice.lines,
    vatBreakdown: vatBreakdown ?? invoice.vatBreakdown,
    totals: invoice.totals,
    allowancesAndCharges: invoice.allowancesAndCharges,
    invoicingPeriod: invoice.invoicingPeriod,
    paymentInstructions: invoice.paymentInstructions,
    supportingDocuments: invoice.supportingDocuments,
    notes: invoice.notes,
  );
}

Set<String> _broken(Invoice invoice) =>
    validatePeppol(invoice).map((violation) => violation.rule.id).toSet();

void main() {
  group('coverage', () {
    test('every Peppol rule has an answer', () {
      final catalogue = peppolCatalogue.map((rule) => rule.id).toSet();
      expect(catalogue, hasLength(59));
      expect(
        catalogue.difference(accountedPeppolRules),
        isEmpty,
        reason: 'Rules Peppol publishes and this package does not answer',
      );
      expect(
        accountedPeppolRules.difference(catalogue),
        isEmpty,
        reason: 'Rules answered under an identifier Peppol does not use',
      );
    });

    test('the three answers never overlap', () {
      expect(
        implementedPeppolRules.intersection(
          peppolMetByConstruction.keys.toSet(),
        ),
        isEmpty,
      );
      expect(
        implementedPeppolRules.intersection(peppolForTheSyntax.keys.toSet()),
        isEmpty,
      );
    });

    test('an unknown identifier is refused', () {
      expect(() => peppolRuleFor('PEPPOL-EN16931-R999'), throwsArgumentError);
    });
  });

  group('an invoice ready for the network', () {
    test('breaks nothing', () {
      expect(validatePeppol(_peppol()), isEmpty);
    });

    test('still goes through the rules of the standard', () {
      // Peppol narrows an invoice that is already an invoice, so a breach of
      // EN 16931 comes back from here too.
      final invoice = _peppol(
        lines: [
          InvoiceLine.of(
            id: '1',
            item: const Item(name: ''),
            quantity: 1,
            unitPrice: 10,
            vatRate: 21,
          ),
        ],
      );
      expect(_broken(invoice), contains('BR-25'));
    });
  });

  group('the profile is claimed', () {
    test('R004 wants the Peppol specification identifier', () {
      expect(
        _broken(_peppol(specificationIdentifier: en16931Specification)),
        contains('PEPPOL-EN16931-R004'),
      );
    });

    test('R001 wants a business process', () {
      expect(
        _broken(_peppol(businessProcess: null)),
        contains('PEPPOL-EN16931-R001'),
      );
    });

    test('R007 wants it in the shape Peppol reads', () {
      final broken = _broken(_peppol(businessProcess: 'billing'));
      expect(broken, contains('PEPPOL-EN16931-R007'));
      expect(broken, isNot(contains('PEPPOL-EN16931-R001')));
    });
  });

  group('what an invoice has to carry', () {
    test('R003 wants a buyer or order reference', () {
      expect(
        _broken(_peppol(buyerReference: null)),
        contains('PEPPOL-EN16931-R003'),
      );
    });

    test('R010 and R020 want both electronic addresses', () {
      const seller = Seller(
        name: 'COMAPPS SRL',
        vatIdentifier: 'BE0123456789',
        address: Address(country: 'BE'),
      );
      const buyer = Buyer(name: 'Client SA', address: Address(country: 'BE'));
      final broken = _broken(_peppol(seller: seller, buyer: buyer));
      expect(
        broken,
        containsAll(['PEPPOL-EN16931-R010', 'PEPPOL-EN16931-R020']),
      );
    });

    test('R002 allows one note, and two between German parties', () {
      const notes = [InvoiceNote('One'), InvoiceNote('Two')];
      expect(_broken(_peppol(notes: notes)), contains('PEPPOL-EN16931-R002'));

      const german = Seller(
        name: 'Ein Verkaufer',
        vatIdentifier: 'DE123456789',
        electronicAddress: Identifier('0123456749', scheme: '0208'),
        address: Address(country: 'DE'),
      );
      const germanBuyer = Buyer(
        name: 'Ein Kaufer',
        electronicAddress: Identifier('0987654394', scheme: '0208'),
        address: Address(country: 'DE'),
      );
      expect(
        _broken(_peppol(notes: notes, seller: german, buyer: germanBuyer)),
        isNot(contains('PEPPOL-EN16931-R002')),
      );
    });

    test('R005 refuses an accounting currency that is the invoice one', () {
      expect(
        _broken(_peppol(vatAccountingCurrency: 'EUR')),
        contains('PEPPOL-EN16931-R005'),
      );
    });

    test('R061 wants a mandate for a direct debit', () {
      const instructions = PaymentInstructions(
        means: PaymentMeansCode.sepaDirectDebit,
        directDebit: DirectDebit(creditorIdentifier: 'BE68ZZZ0123456789'),
      );
      expect(
        _broken(_peppol(paymentInstructions: instructions)),
        contains('PEPPOL-EN16931-R061'),
      );
    });
  });

  group('what has to add up', () {
    test('R041 and R042 want a base and a percentage together', () {
      final allowance = DocumentAllowanceCharge(
        kind: AllowanceOrCharge.allowance,
        amount: _d('50.00'),
        percentage: _d('4'),
        vatCategory: VatCategory.standardRate,
        vatRate: _d('21'),
        reasonCode: '95',
      );
      expect(
        _broken(_peppol(allowancesAndCharges: [allowance])),
        contains('PEPPOL-EN16931-R041'),
      );
    });

    test('R040 wants the amount to be the percentage of the base', () {
      final allowance = DocumentAllowanceCharge(
        kind: AllowanceOrCharge.allowance,
        amount: _d('50.00'),
        baseAmount: _d('1200.00'),
        percentage: _d('10'),
        vatCategory: VatCategory.standardRate,
        vatRate: _d('21'),
        reasonCode: '95',
      );
      expect(
        _broken(_peppol(allowancesAndCharges: [allowance])),
        contains('PEPPOL-EN16931-R040'),
      );
    });

    test('R120 wants the line to be quantity times price', () {
      final line = InvoiceLine(
        id: '1',
        quantity: _d('8'),
        unit: UnitCode.hour,
        netAmount: _d('999.00'),
        item: const Item(name: 'Consulting'),
        price: Price(netPrice: _d('150.00')),
        vatCategory: VatCategory.standardRate,
        vatRate: _d('21'),
      );
      expect(
        _broken(_peppol(lines: [line])),
        contains('PEPPOL-EN16931-R120'),
      );
    });

    test('R121 refuses a base quantity of zero or less', () {
      final line = InvoiceLine(
        id: '1',
        quantity: _d('8'),
        unit: UnitCode.hour,
        netAmount: _d('1200.00'),
        item: const Item(name: 'Consulting'),
        price: Price(netPrice: _d('150.00'), baseQuantity: Decimal.zero),
        vatCategory: VatCategory.standardRate,
        vatRate: _d('21'),
      );
      expect(
        _broken(_peppol(lines: [line])),
        contains('PEPPOL-EN16931-R121'),
      );
    });

    test('R130 wants the base quantity counted in the line unit', () {
      final line = InvoiceLine(
        id: '1',
        quantity: _d('8'),
        unit: UnitCode.hour,
        netAmount: _d('1200.00'),
        item: const Item(name: 'Consulting'),
        price: Price(
          netPrice: _d('150.00'),
          baseQuantity: Decimal.one,
          baseQuantityUnit: UnitCode.day,
        ),
        vatCategory: VatCategory.standardRate,
        vatRate: _d('21'),
      );
      expect(
        _broken(_peppol(lines: [line])),
        contains('PEPPOL-EN16931-R130'),
      );
    });

    test('R046 wants the net price to follow from the gross price', () {
      final line = InvoiceLine(
        id: '1',
        quantity: _d('8'),
        unit: UnitCode.hour,
        netAmount: _d('1200.00'),
        item: const Item(name: 'Consulting'),
        price: Price(
          netPrice: _d('150.00'),
          grossPrice: _d('200.00'),
          discount: _d('10.00'),
        ),
        vatCategory: VatCategory.standardRate,
        vatRate: _d('21'),
      );
      expect(
        _broken(_peppol(lines: [line])),
        contains('PEPPOL-EN16931-R046'),
      );
    });
  });

  group('the code lists Peppol narrows', () {
    test('CL008 refuses a scheme the Peppol list dropped', () {
      // The Peppol electronic address list is shorter than the one the
      // standard allows, which is the whole point of a profile.
      const seller = Seller(
        name: 'COMAPPS SRL',
        vatIdentifier: 'BE0123456789',
        electronicAddress: Identifier('0123456749', scheme: 'KBO'),
        address: Address(country: 'BE'),
      );
      expect(
        _broken(_peppol(seller: seller)),
        contains('PEPPOL-EN16931-CL008'),
      );
    });

    test('CL002 refuses an allowance reason code outside the subset', () {
      final allowance = DocumentAllowanceCharge(
        kind: AllowanceOrCharge.allowance,
        amount: _d('50.00'),
        vatCategory: VatCategory.standardRate,
        vatRate: _d('21'),
        reasonCode: '1',
      );
      expect(
        _broken(_peppol(allowancesAndCharges: [allowance])),
        contains('PEPPOL-EN16931-CL002'),
      );
    });

    test('CL006 allows only the three VAT point date codes', () {
      expect(peppolPeriodCodes, {'3', '35', '432'});
    });

    test('the Peppol address list is shorter than the standard one', () {
      expect(
        peppolElectronicAddressSchemes.length,
        lessThan(cefEasSchemes.length),
      );
    });
  });

  group('type codes and VAT categories', () {
    test('P0100 refuses a type code the billing process does not take', () {
      expect(
        _broken(_peppol(typeCode: const InvoiceTypeCode('999'))),
        contains('PEPPOL-EN16931-P0100'),
      );
    });

    test('P0112 keeps 326 and 384 for German invoices', () {
      expect(
        _broken(_peppol(typeCode: const InvoiceTypeCode('326'))),
        contains('PEPPOL-EN16931-P0112'),
      );
    });

    test('P0106 ties VATEX-EU-IC to the intra-community category', () {
      final breakdown = [
        VatBreakdown(
          category: VatCategory.exempt,
          taxableAmount: _d('1200.00'),
          taxAmount: Decimal.zero,
          rate: Decimal.zero,
          exemptionReasonCode: 'VATEX-EU-IC',
        ),
      ];
      expect(
        _broken(_peppol(vatBreakdown: breakdown)),
        contains('PEPPOL-EN16931-P0106'),
      );
    });
  });

  group('national identifiers', () {
    test('R043 reads a Belgian enterprise number', () {
      expect(isBelgianEnterprise('0123456749'), isTrue);
      expect(isBelgianEnterprise('0123456789'), isFalse);
      const seller = Seller(
        name: 'COMAPPS SRL',
        vatIdentifier: 'BE0123456789',
        electronicAddress: Identifier('0123456789', scheme: '0208'),
        address: Address(country: 'BE'),
      );
      expect(
        _broken(_peppol(seller: seller)),
        contains('PEPPOL-COMMON-R043'),
      );
    });

    test('the checks hold against numbers that are really issued', () {
      expect(isAustralianBusinessNumber('51824753556'), isTrue);
      expect(isNorwegianOrganisation('974760673'), isTrue);
      expect(isSwedishOrganisation('5560360793'), isTrue);
      expect(isGln('7300010000001'), isTrue);
      expect(isDanishCvr('DK12345678'), isTrue);
    });

    test('a mistyped number is caught', () {
      expect(isAustralianBusinessNumber('12345678901'), isFalse);
      expect(isNorwegianOrganisation('974760674'), isFalse);
      expect(isGln('7300010000002'), isFalse);
      expect(isDanishCvr('12345678'), isFalse);
    });

    test('a scheme no rule claims is left alone', () {
      expect(checkFor('9999'), isNull);
    });
  });
}

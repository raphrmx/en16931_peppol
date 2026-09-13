import 'package:decimal/decimal.dart';
import 'package:en16931/en16931.dart';
import 'package:en16931_peppol/src/catalogue.g.dart';
import 'package:en16931_peppol/src/identifiers.dart';
import 'package:en16931_peppol/src/profile.dart';

/// Checks one Peppol rule against an invoice.
typedef PeppolCheck = Iterable<RuleViolation> Function(
    Invoice invoice, RuleDescriptor rule);

/// The type codes the billing process accepts on an invoice.
const Set<String> _invoiceTypes = {
  '71',
  '80',
  '82',
  '84',
  '102',
  '218',
  '219',
  '326',
  '331',
  '380',
  '382',
  '383',
  '384',
  '386',
  '388',
  '393',
  '395',
  '553',
  '575',
  '623',
  '780',
  '817',
  '870',
  '875',
  '876',
  '877',
};

/// The type codes the billing process accepts on a credit note.
const Set<String> _creditNoteTypes = {'381', '396', '81', '83', '532'};

/// The type codes UBL carries under its CreditNote root.
const Set<String> _creditNoteDocuments = {'381', '396', '532'};

/// The type codes only a German invoice may use.
const Set<String> _germanOnlyTypes = {'326', '384'};

/// Which VAT category a VATEX exemption reason code commits the breakdown to.
const Map<String, (String rule, VatCategory category)> _vatexCategories = {
  'VATEX-EU-G': ('PEPPOL-EN16931-P0104', VatCategory.exportOutsideEu),
  'VATEX-EU-O': ('PEPPOL-EN16931-P0105', VatCategory.outsideScope),
  'VATEX-EU-IC': ('PEPPOL-EN16931-P0106', VatCategory.intraCommunitySupply),
  'VATEX-EU-AE': ('PEPPOL-EN16931-P0107', VatCategory.reverseCharge),
  'VATEX-EU-D': ('PEPPOL-EN16931-P0108', VatCategory.exempt),
  'VATEX-EU-F': ('PEPPOL-EN16931-P0109', VatCategory.exempt),
  'VATEX-EU-I': ('PEPPOL-EN16931-P0110', VatCategory.exempt),
  'VATEX-EU-J': ('PEPPOL-EN16931-P0111', VatCategory.exempt),
};

/// Which scheme each national identifier rule is about.
const Map<String, String> _identifierSchemes = {
  'PEPPOL-COMMON-R040': '0088',
  'PEPPOL-COMMON-R041': '0192',
  'PEPPOL-COMMON-R042': '0184',
  'PEPPOL-COMMON-R043': '0208',
  'PEPPOL-COMMON-R044': '0201',
  'PEPPOL-COMMON-R045': '0210',
  'PEPPOL-COMMON-R046': '9907',
  'PEPPOL-COMMON-R047': '0211',
  'PEPPOL-COMMON-R049': '0007',
  'PEPPOL-COMMON-R050': '0151',
  'PEPPOL-COMMON-R052': '0096',
  'PEPPOL-COMMON-R053': '0198',
};

/// What the profile calls each national scheme, for the message.
const Map<String, String> _schemeNames = {
  '0088': 'GLN',
  '0192': 'Norwegian organisation number',
  '0184': 'Danish CVR number',
  '0208': 'Belgian enterprise number',
  '0201': 'Italian IPA code',
  '0210': 'Italian fiscal code',
  '9907': 'Italian fiscal code',
  '0211': 'Italian VAT code',
  '0007': 'Swedish organisation number',
  '0151': 'Australian Business Number',
  '0096': 'Danish production unit number',
  '0198': 'Danish CVR number',
};

/// The rules Peppol adds that this package checks.
final Map<String, PeppolCheck> peppolRules = {
  'PEPPOL-EN16931-R001': _r001,
  'PEPPOL-EN16931-R002': _r002,
  'PEPPOL-EN16931-R003': _r003,
  'PEPPOL-EN16931-R004': _r004,
  'PEPPOL-EN16931-R005': _r005,
  'PEPPOL-EN16931-R007': _r007,
  'PEPPOL-EN16931-R010': _r010,
  'PEPPOL-EN16931-R020': _r020,
  'PEPPOL-EN16931-R040': _r040,
  'PEPPOL-EN16931-R041': _r041,
  'PEPPOL-EN16931-R042': _r042,
  'PEPPOL-EN16931-R046': _r046,
  'PEPPOL-EN16931-R055': _r055,
  'PEPPOL-EN16931-R061': _r061,
  'PEPPOL-EN16931-R110': _r110,
  'PEPPOL-EN16931-R111': _r111,
  'PEPPOL-EN16931-R120': _r120,
  'PEPPOL-EN16931-R121': _r121,
  'PEPPOL-EN16931-R130': _r130,
  'PEPPOL-EN16931-P0100': _p0100,
  'PEPPOL-EN16931-P0101': _p0101,
  'PEPPOL-EN16931-P0112': _p0112,
  'PEPPOL-EN16931-CL001': _cl001,
  'PEPPOL-EN16931-CL002': _cl002,
  'PEPPOL-EN16931-CL003': _cl003,
  'PEPPOL-EN16931-CL006': _cl006,
  'PEPPOL-EN16931-CL007': _cl007,
  'PEPPOL-EN16931-CL008': _cl008,
  for (final entry in _vatexCategories.entries)
    entry.value.$1: (invoice, rule) =>
        _vatex(invoice, rule, entry.key, entry.value.$2),
  for (final entry in _identifierSchemes.entries)
    entry.key: (invoice, rule) => _identifiers(invoice, rule, entry.value),
};

/// The rules an invoice built with this model cannot break.
const Map<String, String> peppolMetByConstruction = {
  'PEPPOL-EN16931-F001': 'A CalendarDate is written as YYYY-MM-DD.',
  'PEPPOL-EN16931-R043':
      'An allowance or a charge is one or the other, never a third thing.',
  'PEPPOL-EN16931-R044': 'A Price carries a discount, never a charge.',
  'PEPPOL-EN16931-R080': 'Invoice.projectReference holds one reference.',
  'PEPPOL-EN16931-R006': 'Invoice.objectIdentifier holds one identifier.',
  'PEPPOL-EN16931-R100': 'InvoiceLine.objectIdentifier holds one identifier.',
};

/// The rules that are about the document rather than the invoice.
///
/// These say how the XML is put together, and a model has no XML. The syntax
/// package satisfies them when it writes, and a document read from elsewhere
/// has to be checked against them before it is read, not after.
const Map<String, String> peppolForTheSyntax = {
  'PEPPOL-EN16931-R008': 'No element may be written empty.',
  'PEPPOL-EN16931-R051':
      'Every currencyID is the invoice currency, save the one in the '
          'accounting currency.',
  'PEPPOL-EN16931-R053': 'One TaxTotal carries the subtotals, and only one.',
  'PEPPOL-EN16931-R054':
      'One TaxTotal carries the accounting currency, and only one.',
  'PEPPOL-EN16931-R101':
      'A document reference on a line is the invoiced object and nothing '
          'else.',
};

// --- What the profile is claimed as ----------------------------------------

Iterable<RuleViolation> _r001(Invoice invoice, RuleDescriptor rule) sync* {
  if (_blank(invoice.businessProcess)) {
    yield _at(
      rule,
      'The business process (BT-23) is missing. Peppol reads it to know which '
      'process the invoice belongs to.',
    );
  }
}

Iterable<RuleViolation> _r007(Invoice invoice, RuleDescriptor rule) sync* {
  final process = invoice.businessProcess;
  if (_blank(process)) return;
  if (!_processFormat.hasMatch(process!)) {
    yield _at(
      rule,
      'The business process (BT-23) is "$process", where Peppol expects '
      'urn:fdc:peppol.eu:2017:poacc:billing:NN:1.0.',
    );
  }
}

final RegExp _processFormat = RegExp(
  '^urn:fdc:peppol.eu:2017:poacc:billing:[0-9]{2}:1.0\$',
);

Iterable<RuleViolation> _r004(Invoice invoice, RuleDescriptor rule) sync* {
  if (invoice.specificationIdentifier != peppolSpecification) {
    yield _at(
      rule,
      'The specification identifier (BT-24) is '
      '"${invoice.specificationIdentifier}", where an invoice sent over '
      'Peppol carries peppolSpecification.',
    );
  }
}

/// The billing process number, or null when the invoice is under another one.
String? _billingProcess(Invoice invoice) {
  final process = invoice.businessProcess;
  if (process == null) return null;
  final match = RegExp(
    '^urn:fdc:peppol.eu:2017:poacc:billing:([0-9]{2}):1.0\$',
  ).firstMatch(process);
  return match?.group(1);
}

// --- What an invoice has to carry ------------------------------------------

Iterable<RuleViolation> _r002(Invoice invoice, RuleDescriptor rule) sync* {
  if (invoice.notes.length <= 1) return;
  if (_isGerman(invoice.seller.address) && _isGerman(invoice.buyer.address)) {
    return;
  }
  yield _at(
    rule,
    'The invoice carries ${invoice.notes.length} notes (BT-22), where Peppol '
    'allows one. Two are allowed only between German parties.',
  );
}

Iterable<RuleViolation> _r003(Invoice invoice, RuleDescriptor rule) sync* {
  if (_blank(invoice.buyerReference) &&
      _blank(invoice.purchaseOrderReference)) {
    yield _at(
      rule,
      'Neither a buyer reference (BT-10) nor a purchase order reference '
      '(BT-13) is given. The buyer needs one of them to book the invoice.',
    );
  }
}

Iterable<RuleViolation> _r005(Invoice invoice, RuleDescriptor rule) sync* {
  final accounting = invoice.vatAccountingCurrency;
  if (accounting == null) return;
  if (accounting == invoice.currency) {
    yield _at(
      rule,
      'The VAT accounting currency (BT-6) is the invoice currency (BT-5). '
      'Peppol asks for it only when the two differ.',
    );
  }
}

Iterable<RuleViolation> _r010(Invoice invoice, RuleDescriptor rule) sync* {
  if (invoice.buyer.electronicAddress == null) {
    yield _at(
      rule,
      'The buyer electronic address (BT-49) is missing. It is the address the '
      'network delivers to.',
    );
  }
}

Iterable<RuleViolation> _r020(Invoice invoice, RuleDescriptor rule) sync* {
  if (invoice.seller.electronicAddress == null) {
    yield _at(
      rule,
      'The seller electronic address (BT-34) is missing. It is the address a '
      'reply is sent to.',
    );
  }
}

Iterable<RuleViolation> _r061(Invoice invoice, RuleDescriptor rule) sync* {
  final debit = invoice.paymentInstructions?.directDebit;
  if (debit == null) return;
  if (_blank(debit.mandateReference)) {
    yield _at(
      rule,
      'Payment is by direct debit, so the mandate reference (BT-89) is '
      'required. It is what the buyer signed.',
    );
  }
}

// --- What has to add up ----------------------------------------------------

Iterable<RuleViolation> _r040(Invoice invoice, RuleDescriptor rule) sync* {
  for (final (index, entry) in invoice.allowancesAndCharges.indexed) {
    final base = entry.baseAmount;
    final percentage = entry.percentage;
    if (base == null || percentage == null) continue;
    final expected = _round2(
      base *
          (percentage / Decimal.fromInt(100)).toDecimal(
            scaleOnInfinitePrecision: 20,
          ),
    );
    if (_round2(entry.amount) == expected) continue;
    yield _at(
      rule,
      'The amount is ${entry.amount} where $percentage% of $base comes to '
          '$expected.',
      'document ${_noun(entry.kind)} $index',
    );
  }
}

Iterable<RuleViolation> _r041(Invoice invoice, RuleDescriptor rule) sync* {
  for (final (index, entry) in invoice.allowancesAndCharges.indexed) {
    if (entry.percentage == null || entry.baseAmount != null) continue;
    yield _at(
      rule,
      'A percentage is given without the base amount it applies to.',
      'document ${_noun(entry.kind)} $index',
    );
  }
}

Iterable<RuleViolation> _r042(Invoice invoice, RuleDescriptor rule) sync* {
  for (final (index, entry) in invoice.allowancesAndCharges.indexed) {
    if (entry.baseAmount == null || entry.percentage != null) continue;
    yield _at(
      rule,
      'A base amount is given without the percentage that applies to it.',
      'document ${_noun(entry.kind)} $index',
    );
  }
}

Iterable<RuleViolation> _r046(Invoice invoice, RuleDescriptor rule) sync* {
  for (final line in invoice.lines) {
    final gross = line.price.grossPrice;
    if (gross == null) continue;
    final discount = line.price.discount ?? Decimal.zero;
    final expected = _round2(gross - discount);
    if (_round2(line.price.netPrice) == expected) continue;
    yield _at(
      rule,
      'The item net price (BT-146) is ${line.price.netPrice} where the gross '
          'price less the discount comes to $expected.',
      'line ${line.id}',
    );
  }
}

Iterable<RuleViolation> _r055(Invoice invoice, RuleDescriptor rule) sync* {
  final vat = invoice.totals.totalVat;
  final accounting = invoice.totals.totalVatInAccountingCurrency;
  if (vat == null || accounting == null) return;
  if (vat.sign == accounting.sign) return;
  yield _at(
    rule,
    'The VAT total (BT-110) is $vat and the same total in the accounting '
    'currency (BT-111) is $accounting. One cannot be owed while the other is '
    'refunded.',
  );
}

Iterable<RuleViolation> _r120(Invoice invoice, RuleDescriptor rule) sync* {
  for (final line in invoice.lines) {
    final base = line.price.baseQuantity;
    if (base != null && base == Decimal.zero) continue;
    final unitPrice = base == null
        ? line.price.netPrice
        : (line.price.netPrice / base).toDecimal(
            scaleOnInfinitePrecision: 20,
          );
    var expected = line.quantity * unitPrice;
    for (final entry in line.allowancesAndCharges) {
      expected = entry.kind == AllowanceOrCharge.charge
          ? expected + entry.amount
          : expected - entry.amount;
    }
    if (_round2(line.netAmount) == _round2(expected)) continue;
    yield _at(
      rule,
      'The line net amount (BT-131) is ${line.netAmount} where the quantity '
          'at the item price, with its allowances and charges, comes to '
          '${_round2(expected)}.',
      'line ${line.id}',
    );
  }
}

Iterable<RuleViolation> _r121(Invoice invoice, RuleDescriptor rule) sync* {
  for (final line in invoice.lines) {
    final base = line.price.baseQuantity;
    if (base == null || base > Decimal.zero) continue;
    yield _at(
      rule,
      'The price base quantity (BT-149) is $base, and a quantity a price is '
          'given for is above zero.',
      'line ${line.id}',
    );
  }
}

Iterable<RuleViolation> _r130(Invoice invoice, RuleDescriptor rule) sync* {
  for (final line in invoice.lines) {
    final unit = line.price.baseQuantityUnit;
    if (unit == null || unit == line.unit) continue;
    yield _at(
      rule,
      'The price base quantity is counted in $unit where the line is counted '
          'in ${line.unit}.',
      'line ${line.id}',
    );
  }
}

// --- Periods ---------------------------------------------------------------

Iterable<RuleViolation> _r110(Invoice invoice, RuleDescriptor rule) sync* {
  yield* _linePeriod(invoice, rule, start: true);
}

Iterable<RuleViolation> _r111(Invoice invoice, RuleDescriptor rule) sync* {
  yield* _linePeriod(invoice, rule, start: false);
}

Iterable<RuleViolation> _linePeriod(
  Invoice invoice,
  RuleDescriptor rule, {
  required bool start,
}) sync* {
  final invoicePeriod = invoice.invoicingPeriod;
  if (invoicePeriod == null) return;
  for (final line in invoice.lines) {
    final period = line.period;
    if (period == null) continue;
    final date = start ? period.start : period.end;
    if (date == null) continue;
    final from = invoicePeriod.start;
    final to = invoicePeriod.end;
    if (from != null && date < from || to != null && date > to) {
      yield _at(
        rule,
        'The line period ${start ? 'starts' : 'ends'} on $date, outside the '
            'invoicing period (BG-14).',
        'line ${line.id}',
      );
    }
  }
}

// --- Which codes are allowed -----------------------------------------------

Iterable<RuleViolation> _cl001(Invoice invoice, RuleDescriptor rule) sync* {
  for (final (index, document) in invoice.supportingDocuments.indexed) {
    final mime = document.attachment?.mimeCode;
    if (mime == null || peppolMimeTypes.contains(mime)) continue;
    yield _at(
      rule,
      'The attachment is "$mime", which Peppol does not carry.',
      'supporting document $index',
    );
  }
}

Iterable<RuleViolation> _cl002(Invoice invoice, RuleDescriptor rule) sync* {
  yield* _reasonCodes(
    invoice,
    rule,
    AllowanceOrCharge.allowance,
    peppolAllowanceReasons,
  );
}

Iterable<RuleViolation> _cl003(Invoice invoice, RuleDescriptor rule) sync* {
  yield* _reasonCodes(
    invoice,
    rule,
    AllowanceOrCharge.charge,
    peppolChargeReasons,
  );
}

Iterable<RuleViolation> _reasonCodes(
  Invoice invoice,
  RuleDescriptor rule,
  AllowanceOrCharge kind,
  Set<String> allowed,
) sync* {
  final noun = _noun(kind);
  for (final (index, entry) in invoice.allowancesAndCharges.indexed) {
    if (entry.kind != kind) continue;
    final code = entry.reasonCode;
    if (code == null || allowed.contains(code)) continue;
    yield _at(
      rule,
      'The reason code is "$code", which the list Peppol narrows does not '
          'hold.',
      'document $noun $index',
    );
  }
  for (final line in invoice.lines) {
    for (final (index, entry) in line.allowancesAndCharges.indexed) {
      if (entry.kind != kind) continue;
      final code = entry.reasonCode;
      if (code == null || allowed.contains(code)) continue;
      yield _at(
        rule,
        'The reason code is "$code", which the list Peppol narrows does not '
            'hold.',
        'line ${line.id}, $noun $index',
      );
    }
  }
}

Iterable<RuleViolation> _cl006(Invoice invoice, RuleDescriptor rule) sync* {
  final code = invoice.vatPointDateCode;
  if (code == null || peppolPeriodCodes.contains(code)) return;
  yield _at(
    rule,
    'The VAT point date code (BT-8) is "$code", where Peppol allows '
    '${peppolPeriodCodes.join(', ')}.',
  );
}

Iterable<RuleViolation> _cl007(Invoice invoice, RuleDescriptor rule) sync* {
  for (final entry in {
    'BT-5': invoice.currency,
    'BT-6': invoice.vatAccountingCurrency,
  }.entries) {
    final code = entry.value;
    if (code == null || code.isEmpty) continue;
    if (peppolCurrencies.contains(code)) continue;
    yield _at(
      rule,
      'The currency (${entry.key}) is "$code", which is not an ISO 4217 code.',
    );
  }
}

Iterable<RuleViolation> _cl008(Invoice invoice, RuleDescriptor rule) sync* {
  final addresses = {
    'seller (BT-34-1)': invoice.seller.electronicAddress,
    'buyer (BT-49-1)': invoice.buyer.electronicAddress,
  };
  for (final entry in addresses.entries) {
    final scheme = entry.value?.scheme;
    if (scheme == null || peppolElectronicAddressSchemes.contains(scheme)) {
      continue;
    }
    yield _at(
      rule,
      'The electronic address scheme of the ${entry.key} is "$scheme", which '
      'the Peppol list does not hold. The list is shorter than the one the '
      'standard allows.',
    );
  }
}

// --- Type codes and VAT categories -----------------------------------------

Iterable<RuleViolation> _p0100(Invoice invoice, RuleDescriptor rule) sync* {
  if (_billingProcess(invoice) != '01') return;
  final code = invoice.typeCode.value;
  if (_creditNoteDocuments.contains(code)) return;
  if (_invoiceTypes.contains(code)) return;
  yield _at(
    rule,
    'The invoice type code (BT-3) is "$code", which the billing process does '
    'not accept.',
  );
}

Iterable<RuleViolation> _p0101(Invoice invoice, RuleDescriptor rule) sync* {
  if (_billingProcess(invoice) != '01') return;
  final code = invoice.typeCode.value;
  if (!_creditNoteDocuments.contains(code)) return;
  if (_creditNoteTypes.contains(code)) return;
  yield _at(
    rule,
    'The credit note type code (BT-3) is "$code", which the billing process '
    'does not accept.',
  );
}

Iterable<RuleViolation> _p0112(Invoice invoice, RuleDescriptor rule) sync* {
  if (!_germanOnlyTypes.contains(invoice.typeCode.value)) return;
  if (_isGerman(invoice.seller.address) && _isGerman(invoice.buyer.address)) {
    return;
  }
  yield _at(
    rule,
    'The type code ${invoice.typeCode} is allowed only when both parties are '
    'German.',
  );
}

Iterable<RuleViolation> _vatex(
  Invoice invoice,
  RuleDescriptor rule,
  String code,
  VatCategory category,
) sync* {
  for (final (index, entry) in invoice.vatBreakdown.indexed) {
    if (entry.exemptionReasonCode != code) continue;
    if (entry.category == category) continue;
    yield _at(
      rule,
      'The exemption reason is $code, which goes with VAT category '
          '$category. The breakdown says ${entry.category}.',
      'VAT breakdown $index',
    );
  }
}

// --- National identifiers --------------------------------------------------

Iterable<RuleViolation> _identifiers(
  Invoice invoice,
  RuleDescriptor rule,
  String scheme,
) sync* {
  final check = checkFor(scheme);
  if (check == null) return;
  final name = _schemeNames[scheme] ?? 'identifier';
  for (final (identifier, where) in _identifiersOf(invoice)) {
    if (identifier.scheme != scheme) continue;
    if (check(identifier.value.trim())) continue;
    yield _at(
      rule,
      'The $name of the $where is "${identifier.value}", which is not shaped '
      'the way that scheme shapes them.',
    );
  }
}

/// Every identifier an invoice carries that a scheme could claim.
Iterable<(Identifier, String)> _identifiersOf(Invoice invoice) sync* {
  final seller = invoice.seller;
  for (final identifier in seller.identifiers) {
    yield (identifier, 'seller');
  }
  if (seller.legalRegistrationIdentifier case final id?) yield (id, 'seller');
  if (seller.electronicAddress case final id?) yield (id, 'seller');

  final buyer = invoice.buyer;
  if (buyer.identifier case final id?) yield (id, 'buyer');
  if (buyer.legalRegistrationIdentifier case final id?) yield (id, 'buyer');
  if (buyer.electronicAddress case final id?) yield (id, 'buyer');

  final payee = invoice.payee;
  if (payee?.identifier case final id?) yield (id, 'payee');
  if (payee?.legalRegistrationIdentifier case final id?) yield (id, 'payee');

  if (invoice.delivery?.locationIdentifier case final id?) {
    yield (id, 'delivery location');
  }
}

// --- Helpers ---------------------------------------------------------------

bool _blank(String? value) => value == null || value.trim().isEmpty;

bool _isGerman(Address address) => address.country == 'DE';

String _noun(AllowanceOrCharge kind) =>
    kind == AllowanceOrCharge.allowance ? 'allowance' : 'charge';

Decimal _round2(Decimal value) => value.round(scale: 2);

RuleViolation _at(RuleDescriptor rule, String message, [String? path]) =>
    RuleViolation(rule: rule, message: message, path: path);

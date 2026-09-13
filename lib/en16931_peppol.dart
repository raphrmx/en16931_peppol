/// Peppol BIS Billing 3.0, the profile most of Europe sends invoices under.
///
/// A profile is a narrowing: it says which identifiers an invoice is claimed
/// under, and which rules it has to meet on top of EN 16931. The model and
/// the rules of the standard itself are in `en16931`, and writing the invoice
/// out is a syntax package's business.
library;

export 'src/catalogue.g.dart';
export 'src/identifiers.dart';
export 'src/profile.dart';
export 'src/rules.dart'
    show PeppolCheck, peppolForTheSyntax, peppolMetByConstruction, peppolRules;
export 'src/validator.dart';

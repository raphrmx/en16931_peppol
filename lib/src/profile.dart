/// BT-24 for an invoice claimed under Peppol BIS Billing 3.0.
///
/// A receiver on the network reads this first: it says which rules the
/// invoice expects to be judged by. An invoice sent over Peppol carrying the
/// bare EN 16931 identifier is rejected before anything else is looked at.
const String peppolSpecification =
    'urn:cen.eu:en16931:2017#compliant#urn:fdc:peppol.eu:2017:poacc:billing:3.0';

/// BT-23 for the billing process, which is the one a plain invoice uses.
///
/// The number in the middle is the process. Billing is 01, and the others
/// cover ordering and despatch, which this profile has nothing to do with.
const String peppolBillingProcess =
    'urn:fdc:peppol.eu:2017:poacc:billing:01:1.0';

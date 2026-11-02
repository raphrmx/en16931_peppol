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

/// BT-23 for billing with response, the process in which the buyer has to
/// answer the invoice with an invoice response.
///
/// Peppol reads it as process 02. It came with release 3.0.21 and needs a
/// registration of its own on the network, so a sender uses it only when the
/// receiver has signed up for it.
const String peppolBillingWithResponseProcess =
    'urn:peppol:bis:billing_with_response';

/// BT-23 for the temporary French process of regulated invoices.
///
/// Peppol reads it as the billing process, 01, and accepts it on a UBL
/// document only: the CII artefacts do not list it.
const String peppolFranceRegulatedProcess =
    'urn:peppol:france:billing:regulated';

/// BT-23 for the temporary French process of non-regulated invoices.
///
/// Like [peppolFranceRegulatedProcess], Peppol reads it as the billing
/// process, 01, and accepts it on a UBL document only.
const String peppolFranceNonRegulatedProcess =
    'urn:peppol:france:billing:non-regulated';

/// Every business process (BT-23) Peppol BIS Billing approves, with the
/// process number its rules read it as.
///
/// An invoice under any other identifier breaks PEPPOL-EN16931-R007. Up to
/// release 3.0.20, any `urn:fdc:peppol.eu:2017:poacc:billing:NN:1.0` passed;
/// since 3.0.21 only these do.
const Map<String, String> peppolBusinessProcesses = {
  peppolBillingProcess: '01',
  peppolFranceRegulatedProcess: '01',
  peppolFranceNonRegulatedProcess: '01',
  peppolBillingWithResponseProcess: '02',
};

## 0.1.1

- The README says what this package does not do, and names the packages that
  do it: the model and the rules in `en16931`, and the two syntaxes that write
  the document.

## 0.1.0

First release.

- `peppolSpecification` and `peppolBillingProcess` carry BT-24 and BT-23 for
  an invoice claimed under Peppol BIS Billing 3.0. An invoice sent over the
  network with the bare EN 16931 identifier is refused before it is read.
- `validatePeppol` checks the rules of the standard and the 59 the profile
  adds, in one pass. A violation names the rule the way Peppol names it, so a
  receiver rejecting on PEPPOL-EN16931-R010 points at the same rule.
- Of the 59, 48 are checked here: the profile is claimed correctly, both
  parties carry an electronic address, allowances and charges add up, line
  periods sit inside the invoicing period, the type code belongs to the
  billing process, a VATEX exemption reason matches its VAT category, and the
  codes come from the lists Peppol narrows.
- The national identifier formats are worked out rather than matched: the
  modulo 97 of a Belgian enterprise number, the GS1 check digit of a GLN, the
  modulo 11 of a Norwegian organisation number, the Luhn of a Swedish one and
  the modulus 89 of an Australian Business Number. The Italian fiscal and VAT
  codes are checked for shape only, on purpose: getting a check character
  wrong would refuse a correct invoice, which costs more than letting a
  malformed number through.
- Six rules cannot be broken by an invoice built with this model, and five are
  about how the XML is put together. Both are listed with what they ask rather
  than quietly skipped, in `peppolMetByConstruction` and `peppolForTheSyntax`.
- The Peppol list of electronic address schemes ships with the package. It
  holds 94 codes where the standard allows 104, and that difference is what a
  profile is.
- The catalogue is read from the artefacts OpenPeppol publishes. Those carry
  no licence, so none of their content is reproduced: what is taken is which
  rules exist, how severe each is and which terms it bears on. Every message
  and every check here is this package's own.
- A test fails when a rule of the catalogue has no answer, so what is covered
  is a fact rather than a claim.

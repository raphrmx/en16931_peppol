import 'package:en16931/en16931.dart';
import 'package:en16931_peppol/src/catalogue.g.dart';
import 'package:en16931_peppol/src/rules.dart';

/// The Peppol catalogue, indexed by identifier.
final Map<String, RuleDescriptor> _byIdentifier = {
  for (final rule in peppolCatalogue) rule.id: rule,
};

/// The rule Peppol publishes as [id].
RuleDescriptor peppolRuleFor(String id) {
  final rule = _byIdentifier[id];
  if (rule == null) {
    throw ArgumentError.value(id, 'id', 'Not a rule of Peppol BIS Billing');
  }
  return rule;
}

/// The Peppol rules this package evaluates.
Set<String> get implementedPeppolRules => peppolRules.keys.toSet();

/// Every Peppol rule this package has an answer for, whichever the answer is.
Set<String> get accountedPeppolRules => {
      ...peppolRules.keys,
      ...peppolMetByConstruction.keys,
      ...peppolForTheSyntax.keys,
    };

/// What [invoice] breaks, under the standard and under Peppol.
///
/// The standard comes first, then the profile, because a profile narrows a
/// document that is already an invoice. An empty result means the invoice is
/// ready for the network as far as its content goes: what is left is the
/// document itself, and a syntax package answers for that.
List<RuleViolation> validatePeppol(Invoice invoice) {
  final violations = validate(invoice);
  for (final entry in peppolRules.entries) {
    violations.addAll(entry.value(invoice, peppolRuleFor(entry.key)));
  }
  violations.sort((a, b) => a.rule.id.compareTo(b.rule.id));
  return violations;
}

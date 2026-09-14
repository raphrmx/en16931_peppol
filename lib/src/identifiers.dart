/// Whether an identifier issued under one scheme is shaped the way that
/// scheme shapes them.
///
/// Peppol checks the format of the national identifiers it knows, because a
/// receiver looks its supplier up by that number and a mistyped one finds
/// nobody. Only the schemes the rules name are checked; any other identifier
/// passes, since no rule claims it.
library;

/// The check on the scheme, or null when no rule claims that scheme.
bool Function(String value)? checkFor(String scheme) => _checks[scheme];

const Map<String, bool Function(String)> _checks = {
  '0088': isGln,
  '0192': isNorwegianOrganisation,
  '0184': isDanishCvr,
  '0198': isDanishCvr,
  '0096': isDanishPNumber,
  '0208': isBelgianEnterprise,
  '0007': isSwedishOrganisation,
  '0151': isAustralianBusinessNumber,
  '0201': isItalianIpaCode,
  '0210': isItalianFiscalCode,
  '9907': isItalianFiscalCode,
  '0211': isItalianVatCode,
  '9906': isItalianVatCode,
};

/// A GLN, which is digits closed by the GS1 check digit.
bool isGln(String value) {
  if (!_digitsOnly(value) || value.isEmpty) return false;
  final digits = value.split('').map(int.parse).toList();
  final check = digits.removeLast();
  var sum = 0;
  // GS1 weights the digits three and one, counting from the right.
  for (var index = 0; index < digits.length; index++) {
    final weight = (digits.length - index).isOdd ? 3 : 1;
    sum += digits[index] * weight;
  }
  return (10 - sum % 10) % 10 == check;
}

/// A Norwegian organisation number: nine digits closed by a modulo 11 digit.
bool isNorwegianOrganisation(String value) {
  if (value.length != 9 || !_digitsOnly(value)) return false;
  const weights = [3, 2, 7, 6, 5, 4, 3, 2];
  var sum = 0;
  for (var index = 0; index < weights.length; index++) {
    sum += int.parse(value[index]) * weights[index];
  }
  final remainder = sum % 11;
  final check = remainder == 0 ? 0 : 11 - remainder;
  // A remainder of one leaves no valid check digit, and those numbers are
  // never issued.
  if (check == 10) return false;
  return check == int.parse(value[8]);
}

/// A Danish CVR number, written as DK and eight digits.
bool isDanishCvr(String value) =>
    value.length == 10 &&
    value.startsWith('DK') &&
    _digitsOnly(value.substring(2));

/// A Danish production unit number, which is ten digits.
bool isDanishPNumber(String value) => value.length == 10 && _digitsOnly(value);

/// A Belgian enterprise number: ten digits whose last two are 97 less the
/// first eight taken modulo 97.
bool isBelgianEnterprise(String value) {
  if (value.length != 10 || !_digitsOnly(value)) return false;
  final body = int.parse(value.substring(0, 8));
  final check = int.parse(value.substring(8));
  return 97 - body % 97 == check;
}

/// A Swedish organisation number: ten digits closed by a Luhn digit.
bool isSwedishOrganisation(String value) {
  if (value.length != 10 || !_digitsOnly(value)) return false;
  return _luhn(value);
}

/// An Australian Business Number: eleven digits that weigh out to a multiple
/// of 89 once one is taken off the first.
bool isAustralianBusinessNumber(String value) {
  if (value.length != 11 || !_digitsOnly(value)) return false;
  const weights = [10, 1, 3, 5, 7, 9, 11, 13, 15, 17, 19];
  var sum = 0;
  for (var index = 0; index < weights.length; index++) {
    final digit = int.parse(value[index]) - (index == 0 ? 1 : 0);
    sum += digit * weights[index];
  }
  return sum % 89 == 0;
}

/// An Italian IPA code, which is six letters or digits.
bool isItalianIpaCode(String value) =>
    RegExp(r'^[A-Za-z0-9]{6}$').hasMatch(value);

/// An Italian fiscal code: sixteen letters and digits for a person, or the
/// eleven digits of a company.
///
/// The check character is not worked out here. Getting it wrong would refuse
/// a correct invoice, which costs more than letting a malformed number
/// through, and the rule that carries it is a warning rather than a
/// rejection.
bool isItalianFiscalCode(String value) =>
    RegExp(r'^[A-Za-z0-9]{16}$').hasMatch(value) ||
    RegExp(r'^[0-9]{11}$').hasMatch(value);

/// An Italian VAT code, which is eleven digits, with or without its country
/// prefix.
///
/// As with the fiscal code, the check digit is left alone on purpose.
bool isItalianVatCode(String value) {
  final digits = value.toUpperCase().startsWith('IT')
      ? value.substring(2)
      : value;
  return RegExp(r'^[0-9]{11}$').hasMatch(digits);
}

bool _digitsOnly(String value) => RegExp(r'^[0-9]+$').hasMatch(value);

/// The Luhn check, which closes a number with a digit that makes the weighted
/// sum a multiple of ten.
bool _luhn(String value) {
  var sum = 0;
  var double = false;
  for (var index = value.length - 1; index >= 0; index--) {
    var digit = int.parse(value[index]);
    if (double) {
      digit *= 2;
      if (digit > 9) digit -= 9;
    }
    sum += digit;
    double = !double;
  }
  return sum % 10 == 0;
}

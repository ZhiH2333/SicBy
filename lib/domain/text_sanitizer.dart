String sanitizeDisplayText(String value) {
  if (value.isEmpty) return value;
  var cleaned = value
      .replaceAll('\u200B', '')
      .replaceAll('\u200C', '')
      .replaceAll('\u200D', '')
      .replaceAll('\uFEFF', '')
      .replaceAll('\u00A0', ' ');
  cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  return cleaned;
}

String? sanitizeDisplayTextOptional(String? value) {
  if (value == null) return null;
  final cleaned = sanitizeDisplayText(value);
  return cleaned.isEmpty ? null : cleaned;
}

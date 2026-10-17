/// Time-based greeting for the home header, e.g. "Good afternoon, Saad".
///
/// Morning 5-12, Afternoon 12-17, Evening 17-21, Night 21-5. Only the first
/// word of [name] is used; a blank or missing name gives the bare greeting.
String greetingFor(DateTime now, {String? name}) {
  final hour = now.hour;
  final String part;
  if (hour >= 5 && hour < 12) {
    part = 'morning';
  } else if (hour >= 12 && hour < 17) {
    part = 'afternoon';
  } else if (hour >= 17 && hour < 21) {
    part = 'evening';
  } else {
    part = 'night';
  }
  final first = firstName(name);
  return first == null ? 'Good $part' : 'Good $part, $first';
}

/// First word of [name], or null when it is missing or blank.
String? firstName(String? name) {
  final trimmed = name?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  return trimmed.split(RegExp(r'\s+')).first;
}

/// Turns thrown objects into short messages suitable for the UI.
String userFacingError(Object error) {
  if (error is ArgumentError) {
    final message = error.message;
    if (message is String && message.isNotEmpty) return message;
  }
  final text = error.toString();
  const prefix = 'Invalid argument(s): ';
  if (text.startsWith(prefix)) return text.substring(prefix.length);
  return text;
}

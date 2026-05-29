/// Thrown when a direct file URL cannot be fetched (blocked, missing, etc.).
class DirectLinkAccessException implements Exception {
  const DirectLinkAccessException(this.message);

  final String message;

  @override
  String toString() => message;
}

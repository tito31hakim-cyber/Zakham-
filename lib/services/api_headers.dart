/// Credentials are intentionally kept in memory by the caller.
/// Do not persist adminToken or csrfToken in SharedPreferences or logs.
/// (The customer session cookie is the one exception: CustomerProvider
/// persists it separately, in encrypted secure storage only — never in
/// plain SharedPreferences.)
class ApiCredentials {
  const ApiCredentials({
    this.bearerToken,
    this.adminToken,
    this.csrfToken,
    this.cookie,
  });

  final String? bearerToken;
  final String? adminToken;
  final String? csrfToken;

  /// Session cookie (e.g. `PHPSESSID=...`). This object itself never
  /// persists anything: the admin session lives in memory only, while
  /// the customer session cookie is persisted by CustomerProvider in
  /// encrypted secure storage (never in plain SharedPreferences).
  /// The store backend authenticates admins with PHP sessions.
  final String? cookie;
}

class ApiHeaders {
  ApiHeaders._();

  static Map<String, String> build({
    ApiCredentials? credentials,
    bool json = false,
    bool mutating = false,
  }) {
    final headers = <String, String>{
      'Accept': 'application/json',
      'User-Agent': 'HouseOfZakham/1.1 (Flutter; Android/iOS)',
      'X-API-Client': 'house-of-zakham-mobile',
      if (json) 'Content-Type': 'application/json',
    };

    final bearer = credentials?.bearerToken?.trim();
    final admin = credentials?.adminToken?.trim();
    final csrf = credentials?.csrfToken?.trim();
    final cookie = credentials?.cookie?.trim();

    if (bearer != null && bearer.isNotEmpty) {
      headers['Authorization'] = 'Bearer $bearer';
    }
    // Kept for compatibility with the current PHP admin() implementation.
    if (admin != null && admin.isNotEmpty) {
      headers['X-Admin-Token'] = admin;
    }
    if (mutating && csrf != null && csrf.isNotEmpty) {
      headers['X-CSRF-Token'] = csrf;
    }
    if (cookie != null && cookie.isNotEmpty) {
      headers['Cookie'] = cookie;
    }

    return headers;
  }
}

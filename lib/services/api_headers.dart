/// Credentials are intentionally kept in memory by the caller.
/// Do not persist adminToken or csrfToken in SharedPreferences or logs.
class ApiCredentials {
  const ApiCredentials({this.bearerToken, this.adminToken, this.csrfToken});

  final String? bearerToken;
  final String? adminToken;
  final String? csrfToken;
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
      'User-Agent': 'HouseOfZakham/1.0 (Flutter; Android/iOS)',
      'X-API-Client': 'house-of-zakham-mobile',
      if (json) 'Content-Type': 'application/json',
    };

    final bearer = credentials?.bearerToken?.trim();
    final admin = credentials?.adminToken?.trim();
    final csrf = credentials?.csrfToken?.trim();

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

    return headers;
  }
}

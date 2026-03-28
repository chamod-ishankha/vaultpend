/// Backend base URL (no trailing slash).
/// Default: LAN API server. Override: `--dart-define=API_BASE_URL=http://host:8080`
String get vaultSpendApiBaseUrl {
  const fromEnv = String.fromEnvironment('API_BASE_URL');
  if (fromEnv.isNotEmpty) return fromEnv;
  return 'http://192.168.1.2:8080';
}

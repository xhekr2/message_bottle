/// Server address. Override at build/run time, e.g.
/// `flutter run --dart-define=API_BASE_URL=http://192.168.0.10:8080`
/// The default works for the Android emulator (10.0.2.2 = host PC).
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8080',
);

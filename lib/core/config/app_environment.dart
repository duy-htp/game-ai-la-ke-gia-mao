enum AppEnvironment {
  development('development'),
  staging('staging'),
  production('production');

  const AppEnvironment(this.value);

  final String value;

  static AppEnvironment parse(String value) {
    return AppEnvironment.values.firstWhere(
      (environment) => environment.value == value.trim().toLowerCase(),
      orElse: () => throw ArgumentError.value(
        value,
        'APP_ENV',
        'Expected development, staging, or production',
      ),
    );
  }
}

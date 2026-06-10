import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:recetarios/data/api_client.dart';

/// Bound at bootstrap (main.dart) once the backend connection is established.
final apiClientProvider = Provider<ApiClient>(
  (ref) => throw UnimplementedError('apiClientProvider must be overridden at bootstrap'),
);

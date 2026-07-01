import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:recetarios/data/local/app_database.dart';
import 'package:recetarios/data/local/archive_service.dart';
import 'package:recetarios/data/local/image_store.dart';
import 'package:recetarios/data/local/legacy_importer.dart';
import 'package:recetarios/data/local/local_repository.dart';
import 'package:recetarios/data/local/pdf_service.dart';
import 'package:recetarios/data/local/settings_store.dart';

final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('appDatabaseProvider must be overridden at bootstrap'),
);

final repositoryProvider = Provider<LocalRepository>(
  (ref) => LocalRepository(ref.watch(appDatabaseProvider)),
);

final imageStoreProvider = Provider<ImageStore>(
  (ref) => ImageStore(ref.watch(appDatabaseProvider)),
);

final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => SettingsStore(ref.watch(appDatabaseProvider)),
);

final archiveServiceProvider = Provider<ArchiveService>(
  (ref) => ArchiveService(
    ref.watch(appDatabaseProvider),
    ref.watch(imageStoreProvider),
    ref.watch(repositoryProvider),
  ),
);

final pdfServiceProvider = Provider<PdfService>(
  (ref) => PdfService(
    ref.watch(appDatabaseProvider),
    ref.watch(imageStoreProvider),
    ref.watch(repositoryProvider),
    ref.watch(settingsStoreProvider),
  ),
);

final legacyImporterProvider = Provider<LegacyImporter>(
  (ref) => LegacyImporter(ref.watch(repositoryProvider), ref.watch(imageStoreProvider)),
);

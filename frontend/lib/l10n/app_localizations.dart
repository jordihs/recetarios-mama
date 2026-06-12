import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('es')];

  /// No description provided for @appTitle.
  ///
  /// In es, this message translates to:
  /// **'Recetarios de mamá'**
  String get appTitle;

  /// No description provided for @books.
  ///
  /// In es, this message translates to:
  /// **'Libros'**
  String get books;

  /// No description provided for @addBook.
  ///
  /// In es, this message translates to:
  /// **'Añadir libro'**
  String get addBook;

  /// No description provided for @editBook.
  ///
  /// In es, this message translates to:
  /// **'Editar libro'**
  String get editBook;

  /// No description provided for @deleteBook.
  ///
  /// In es, this message translates to:
  /// **'Eliminar libro'**
  String get deleteBook;

  /// No description provided for @deleteBookConfirm.
  ///
  /// In es, this message translates to:
  /// **'Se eliminará el libro «{title}» con todos sus capítulos y recetas. ¿Continuar?'**
  String deleteBookConfirm(Object title);

  /// No description provided for @noBooks.
  ///
  /// In es, this message translates to:
  /// **'Todavía no hay libros. Crea el primero o importa un recetario antiguo.'**
  String get noBooks;

  /// No description provided for @chapters.
  ///
  /// In es, this message translates to:
  /// **'Capítulos'**
  String get chapters;

  /// No description provided for @addChapter.
  ///
  /// In es, this message translates to:
  /// **'Añadir capítulo'**
  String get addChapter;

  /// No description provided for @editChapter.
  ///
  /// In es, this message translates to:
  /// **'Editar capítulo'**
  String get editChapter;

  /// No description provided for @deleteChapter.
  ///
  /// In es, this message translates to:
  /// **'Eliminar capítulo'**
  String get deleteChapter;

  /// No description provided for @deleteChapterConfirm.
  ///
  /// In es, this message translates to:
  /// **'Se eliminará el capítulo «{title}» con todos sus subcapítulos y recetas. ¿Continuar?'**
  String deleteChapterConfirm(Object title);

  /// No description provided for @noChapters.
  ///
  /// In es, this message translates to:
  /// **'Este libro todavía no tiene capítulos.'**
  String get noChapters;

  /// No description provided for @subchapters.
  ///
  /// In es, this message translates to:
  /// **'Subcapítulos'**
  String get subchapters;

  /// No description provided for @recipes.
  ///
  /// In es, this message translates to:
  /// **'Recetas'**
  String get recipes;

  /// No description provided for @addRecipe.
  ///
  /// In es, this message translates to:
  /// **'Añadir receta'**
  String get addRecipe;

  /// No description provided for @deleteRecipe.
  ///
  /// In es, this message translates to:
  /// **'Eliminar receta'**
  String get deleteRecipe;

  /// No description provided for @deleteRecipeConfirm.
  ///
  /// In es, this message translates to:
  /// **'Se eliminará la receta «{title}». ¿Continuar?'**
  String deleteRecipeConfirm(Object title);

  /// No description provided for @noRecipes.
  ///
  /// In es, this message translates to:
  /// **'Este capítulo todavía no tiene recetas.'**
  String get noRecipes;

  /// No description provided for @titlesOnly.
  ///
  /// In es, this message translates to:
  /// **'Solo títulos'**
  String get titlesOnly;

  /// No description provided for @detailedView.
  ///
  /// In es, this message translates to:
  /// **'Vista detallada'**
  String get detailedView;

  /// No description provided for @ingredients.
  ///
  /// In es, this message translates to:
  /// **'Ingredientes'**
  String get ingredients;

  /// No description provided for @servings.
  ///
  /// In es, this message translates to:
  /// **'Para {count} personas'**
  String servings(Object count);

  /// No description provided for @preparation.
  ///
  /// In es, this message translates to:
  /// **'Preparación'**
  String get preparation;

  /// No description provided for @introduction.
  ///
  /// In es, this message translates to:
  /// **'Introducción'**
  String get introduction;

  /// No description provided for @note.
  ///
  /// In es, this message translates to:
  /// **'Nota'**
  String get note;

  /// No description provided for @edit.
  ///
  /// In es, this message translates to:
  /// **'Editar'**
  String get edit;

  /// No description provided for @save.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get save;

  /// No description provided for @discardChanges.
  ///
  /// In es, this message translates to:
  /// **'Descartar cambios'**
  String get discardChanges;

  /// No description provided for @unsavedChangesTitle.
  ///
  /// In es, this message translates to:
  /// **'Cambios sin guardar'**
  String get unsavedChangesTitle;

  /// No description provided for @unsavedChangesBody.
  ///
  /// In es, this message translates to:
  /// **'Hay cambios sin guardar. ¿Quieres descartarlos?'**
  String get unsavedChangesBody;

  /// No description provided for @discard.
  ///
  /// In es, this message translates to:
  /// **'Descartar'**
  String get discard;

  /// No description provided for @keepEditing.
  ///
  /// In es, this message translates to:
  /// **'Seguir editando'**
  String get keepEditing;

  /// No description provided for @cancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// No description provided for @accept.
  ///
  /// In es, this message translates to:
  /// **'Aceptar'**
  String get accept;

  /// No description provided for @delete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get delete;

  /// No description provided for @title.
  ///
  /// In es, this message translates to:
  /// **'Título'**
  String get title;

  /// No description provided for @titleRequired.
  ///
  /// In es, this message translates to:
  /// **'El título es obligatorio'**
  String get titleRequired;

  /// No description provided for @description.
  ///
  /// In es, this message translates to:
  /// **'Descripción'**
  String get description;

  /// No description provided for @coverImage.
  ///
  /// In es, this message translates to:
  /// **'Imagen de portada'**
  String get coverImage;

  /// No description provided for @chooseImage.
  ///
  /// In es, this message translates to:
  /// **'Elegir imagen'**
  String get chooseImage;

  /// No description provided for @removeImage.
  ///
  /// In es, this message translates to:
  /// **'Quitar imagen'**
  String get removeImage;

  /// No description provided for @moveUp.
  ///
  /// In es, this message translates to:
  /// **'Subir'**
  String get moveUp;

  /// No description provided for @moveDown.
  ///
  /// In es, this message translates to:
  /// **'Bajar'**
  String get moveDown;

  /// No description provided for @search.
  ///
  /// In es, this message translates to:
  /// **'Buscar'**
  String get search;

  /// No description provided for @searchHint.
  ///
  /// In es, this message translates to:
  /// **'Buscar en todas las recetas…'**
  String get searchHint;

  /// No description provided for @searchNoResults.
  ///
  /// In es, this message translates to:
  /// **'No se han encontrado recetas para «{query}»'**
  String searchNoResults(Object query);

  /// No description provided for @settings.
  ///
  /// In es, this message translates to:
  /// **'Configuración'**
  String get settings;

  /// No description provided for @pdfOutputDir.
  ///
  /// In es, this message translates to:
  /// **'Carpeta de destino para los PDF'**
  String get pdfOutputDir;

  /// No description provided for @chooseFolder.
  ///
  /// In es, this message translates to:
  /// **'Elegir carpeta'**
  String get chooseFolder;

  /// No description provided for @importLegacy.
  ///
  /// In es, this message translates to:
  /// **'Importar recetario antiguo'**
  String get importLegacy;

  /// No description provided for @importLegacyCollisionTitle.
  ///
  /// In es, this message translates to:
  /// **'Ya existe un libro con este título'**
  String get importLegacyCollisionTitle;

  /// No description provided for @importLegacyCollisionBody.
  ///
  /// In es, this message translates to:
  /// **'Ya existe un libro llamado «{title}». ¿Qué quieres hacer?'**
  String importLegacyCollisionBody(Object title);

  /// No description provided for @replaceExisting.
  ///
  /// In es, this message translates to:
  /// **'Reemplazar el existente'**
  String get replaceExisting;

  /// No description provided for @keepBoth.
  ///
  /// In es, this message translates to:
  /// **'Conservar ambos'**
  String get keepBoth;

  /// No description provided for @importReportTitle.
  ///
  /// In es, this message translates to:
  /// **'Importación completada'**
  String get importReportTitle;

  /// No description provided for @importReportBody.
  ///
  /// In es, this message translates to:
  /// **'Capítulos: {chapters}\nRecetas: {recipes}\nImágenes importadas: {images}'**
  String importReportBody(Object chapters, Object recipes, Object images);

  /// No description provided for @importReportMissingImages.
  ///
  /// In es, this message translates to:
  /// **'Imágenes no encontradas:'**
  String get importReportMissingImages;

  /// No description provided for @exportLibrary.
  ///
  /// In es, this message translates to:
  /// **'Exportar biblioteca'**
  String get exportLibrary;

  /// No description provided for @importLibrary.
  ///
  /// In es, this message translates to:
  /// **'Importar biblioteca'**
  String get importLibrary;

  /// No description provided for @importLibraryConfirmTitle.
  ///
  /// In es, this message translates to:
  /// **'Reemplazar toda la biblioteca'**
  String get importLibraryConfirmTitle;

  /// No description provided for @importLibraryConfirmBody.
  ///
  /// In es, this message translates to:
  /// **'Al importar se reemplazará TODA la biblioteca actual (libros, capítulos y recetas). Esta acción no se puede deshacer. ¿Continuar?'**
  String get importLibraryConfirmBody;

  /// No description provided for @exportLibraryDone.
  ///
  /// In es, this message translates to:
  /// **'Biblioteca exportada en {path}'**
  String exportLibraryDone(Object path);

  /// No description provided for @importLibraryDone.
  ///
  /// In es, this message translates to:
  /// **'Biblioteca importada correctamente'**
  String get importLibraryDone;

  /// No description provided for @exportBookPdf.
  ///
  /// In es, this message translates to:
  /// **'Exportar libro a PDF'**
  String get exportBookPdf;

  /// No description provided for @generatingPdf.
  ///
  /// In es, this message translates to:
  /// **'Generando PDF…'**
  String get generatingPdf;

  /// No description provided for @print.
  ///
  /// In es, this message translates to:
  /// **'Imprimir'**
  String get print;

  /// No description provided for @printRecipeTitle.
  ///
  /// In es, this message translates to:
  /// **'Imprimir receta'**
  String get printRecipeTitle;

  /// No description provided for @includeIntroduction.
  ///
  /// In es, this message translates to:
  /// **'Incluir introducción'**
  String get includeIntroduction;

  /// No description provided for @includeImages.
  ///
  /// In es, this message translates to:
  /// **'Incluir imágenes'**
  String get includeImages;

  /// No description provided for @pdfSavedAt.
  ///
  /// In es, this message translates to:
  /// **'PDF guardado en {path}'**
  String pdfSavedAt(Object path);

  /// No description provided for @content.
  ///
  /// In es, this message translates to:
  /// **'Contenido'**
  String get content;

  /// No description provided for @editorBold.
  ///
  /// In es, this message translates to:
  /// **'Negrita'**
  String get editorBold;

  /// No description provided for @editorItalic.
  ///
  /// In es, this message translates to:
  /// **'Cursiva'**
  String get editorItalic;

  /// No description provided for @editorH2.
  ///
  /// In es, this message translates to:
  /// **'Título de sección'**
  String get editorH2;

  /// No description provided for @editorH3.
  ///
  /// In es, this message translates to:
  /// **'Subtítulo'**
  String get editorH3;

  /// No description provided for @editorBulletedList.
  ///
  /// In es, this message translates to:
  /// **'Lista'**
  String get editorBulletedList;

  /// No description provided for @editorInsertTable.
  ///
  /// In es, this message translates to:
  /// **'Insertar tabla'**
  String get editorInsertTable;

  /// No description provided for @editorInsertImage.
  ///
  /// In es, this message translates to:
  /// **'Insertar imagen'**
  String get editorInsertImage;

  /// No description provided for @editorSource.
  ///
  /// In es, this message translates to:
  /// **'Fuente'**
  String get editorSource;

  /// No description provided for @editorSourceOnly.
  ///
  /// In es, this message translates to:
  /// **'Este contenido contiene estructuras que solo se pueden editar en modo fuente.'**
  String get editorSourceOnly;

  /// No description provided for @addGroup.
  ///
  /// In es, this message translates to:
  /// **'Añadir grupo'**
  String get addGroup;

  /// No description provided for @groupTitle.
  ///
  /// In es, this message translates to:
  /// **'Título del grupo (opcional)'**
  String get groupTitle;

  /// No description provided for @addIngredient.
  ///
  /// In es, this message translates to:
  /// **'Añadir ingrediente'**
  String get addIngredient;

  /// No description provided for @servingsLabel.
  ///
  /// In es, this message translates to:
  /// **'Personas (opcional)'**
  String get servingsLabel;

  /// No description provided for @libraryLegacyTitle.
  ///
  /// In es, this message translates to:
  /// **'Biblioteca de una versión anterior'**
  String get libraryLegacyTitle;

  /// No description provided for @libraryLegacyBody.
  ///
  /// In es, this message translates to:
  /// **'Esta biblioteca se creó con una versión anterior de la aplicación y ya no se puede abrir. Para continuar es necesario reiniciarla: se vaciará la biblioteca (las imágenes se conservan) y podrás volver a importar tus recetarios actualizados.'**
  String get libraryLegacyBody;

  /// No description provided for @libraryLegacyResetButton.
  ///
  /// In es, this message translates to:
  /// **'Reiniciar biblioteca'**
  String get libraryLegacyResetButton;

  /// No description provided for @libraryResetConfirmTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Reiniciar la biblioteca?'**
  String get libraryResetConfirmTitle;

  /// No description provided for @libraryResetConfirmBody.
  ///
  /// In es, this message translates to:
  /// **'Se eliminarán todos los libros, capítulos y recetas. Esta acción no se puede deshacer. ¿Continuar?'**
  String get libraryResetConfirmBody;

  /// No description provided for @libraryResetDone.
  ///
  /// In es, this message translates to:
  /// **'Biblioteca reiniciada. Ya puedes importar tus recetarios.'**
  String get libraryResetDone;

  /// No description provided for @errorTitle.
  ///
  /// In es, this message translates to:
  /// **'Error'**
  String get errorTitle;

  /// No description provided for @connectingBackend.
  ///
  /// In es, this message translates to:
  /// **'Iniciando la aplicación…'**
  String get connectingBackend;

  /// No description provided for @backendFailed.
  ///
  /// In es, this message translates to:
  /// **'No se ha podido iniciar el servicio de datos. Vuelve a abrir la aplicación.'**
  String get backendFailed;

  /// No description provided for @loading.
  ///
  /// In es, this message translates to:
  /// **'Cargando…'**
  String get loading;

  /// No description provided for @retry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get retry;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Recetarios de mamá';

  @override
  String get books => 'Libros';

  @override
  String get addBook => 'Añadir libro';

  @override
  String get editBook => 'Editar libro';

  @override
  String get deleteBook => 'Eliminar libro';

  @override
  String deleteBookConfirm(Object title) {
    return 'Se eliminará el libro «$title» con todos sus capítulos y recetas. ¿Continuar?';
  }

  @override
  String get noBooks =>
      'Todavía no hay libros. Crea el primero o importa un recetario antiguo.';

  @override
  String get chapters => 'Capítulos';

  @override
  String get addChapter => 'Añadir capítulo';

  @override
  String get editChapter => 'Editar capítulo';

  @override
  String get deleteChapter => 'Eliminar capítulo';

  @override
  String deleteChapterConfirm(Object title) {
    return 'Se eliminará el capítulo «$title» con todos sus subcapítulos y recetas. ¿Continuar?';
  }

  @override
  String get noChapters => 'Este libro todavía no tiene capítulos.';

  @override
  String get subchapters => 'Subcapítulos';

  @override
  String get recipes => 'Recetas';

  @override
  String get addRecipe => 'Añadir receta';

  @override
  String get deleteRecipe => 'Eliminar receta';

  @override
  String deleteRecipeConfirm(Object title) {
    return 'Se eliminará la receta «$title». ¿Continuar?';
  }

  @override
  String get noRecipes => 'Este capítulo todavía no tiene recetas.';

  @override
  String get titlesOnly => 'Solo títulos';

  @override
  String get detailedView => 'Vista detallada';

  @override
  String get ingredients => 'Ingredientes';

  @override
  String servings(Object count) {
    return 'Para $count personas';
  }

  @override
  String get preparation => 'Preparación';

  @override
  String get introduction => 'Introducción';

  @override
  String get note => 'Nota';

  @override
  String get edit => 'Editar';

  @override
  String get save => 'Guardar';

  @override
  String get discardChanges => 'Descartar cambios';

  @override
  String get unsavedChangesTitle => 'Cambios sin guardar';

  @override
  String get unsavedChangesBody =>
      'Hay cambios sin guardar. ¿Quieres descartarlos?';

  @override
  String get discard => 'Descartar';

  @override
  String get keepEditing => 'Seguir editando';

  @override
  String get cancel => 'Cancelar';

  @override
  String get accept => 'Aceptar';

  @override
  String get delete => 'Eliminar';

  @override
  String get title => 'Título';

  @override
  String get titleRequired => 'El título es obligatorio';

  @override
  String get description => 'Descripción';

  @override
  String get coverImage => 'Imagen de portada';

  @override
  String get chooseImage => 'Elegir imagen';

  @override
  String get removeImage => 'Quitar imagen';

  @override
  String get moveUp => 'Subir';

  @override
  String get moveDown => 'Bajar';

  @override
  String get search => 'Buscar';

  @override
  String get searchHint => 'Buscar en todas las recetas…';

  @override
  String searchNoResults(Object query) {
    return 'No se han encontrado recetas para «$query»';
  }

  @override
  String get settings => 'Configuración';

  @override
  String get pdfOutputDir => 'Carpeta de destino para los PDF';

  @override
  String get chooseFolder => 'Elegir carpeta';

  @override
  String get importLegacy => 'Importar recetario antiguo';

  @override
  String get importLegacyCollisionTitle => 'Ya existe un libro con este título';

  @override
  String importLegacyCollisionBody(Object title) {
    return 'Ya existe un libro llamado «$title». ¿Qué quieres hacer?';
  }

  @override
  String get replaceExisting => 'Reemplazar el existente';

  @override
  String get keepBoth => 'Conservar ambos';

  @override
  String get importReportTitle => 'Importación completada';

  @override
  String importReportBody(Object chapters, Object recipes, Object images) {
    return 'Capítulos: $chapters\nRecetas: $recipes\nImágenes importadas: $images';
  }

  @override
  String get importReportMissingImages => 'Imágenes no encontradas:';

  @override
  String get exportLibrary => 'Exportar biblioteca';

  @override
  String get importLibrary => 'Importar biblioteca';

  @override
  String get importLibraryConfirmTitle => 'Reemplazar toda la biblioteca';

  @override
  String get importLibraryConfirmBody =>
      'Al importar se reemplazará TODA la biblioteca actual (libros, capítulos y recetas). Esta acción no se puede deshacer. ¿Continuar?';

  @override
  String exportLibraryDone(Object path) {
    return 'Biblioteca exportada en $path';
  }

  @override
  String get importLibraryDone => 'Biblioteca importada correctamente';

  @override
  String get exportBookPdf => 'Exportar libro a PDF';

  @override
  String get generatingPdf => 'Generando PDF…';

  @override
  String get print => 'Imprimir';

  @override
  String get printRecipeTitle => 'Imprimir receta';

  @override
  String get includeIntroduction => 'Incluir introducción';

  @override
  String get includeImages => 'Incluir imágenes';

  @override
  String pdfSavedAt(Object path) {
    return 'PDF guardado en $path';
  }

  @override
  String get content => 'Contenido';

  @override
  String get editorBold => 'Negrita';

  @override
  String get editorItalic => 'Cursiva';

  @override
  String get editorH2 => 'Título de sección';

  @override
  String get editorH3 => 'Subtítulo';

  @override
  String get editorBulletedList => 'Lista';

  @override
  String get editorInsertTable => 'Insertar tabla';

  @override
  String get editorInsertImage => 'Insertar imagen';

  @override
  String get editorSource => 'Fuente';

  @override
  String get editorSourceOnly =>
      'Este contenido contiene estructuras que solo se pueden editar en modo fuente.';

  @override
  String get addGroup => 'Añadir grupo';

  @override
  String get groupTitle => 'Título del grupo (opcional)';

  @override
  String get addIngredient => 'Añadir ingrediente';

  @override
  String get servingsLabel => 'Personas (opcional)';

  @override
  String get libraryLegacyTitle => 'Biblioteca de una versión anterior';

  @override
  String get libraryLegacyBody =>
      'Esta biblioteca se creó con una versión anterior de la aplicación y ya no se puede abrir. Para continuar es necesario reiniciarla: se vaciará la biblioteca (las imágenes se conservan) y podrás volver a importar tus recetarios actualizados.';

  @override
  String get libraryLegacyResetButton => 'Reiniciar biblioteca';

  @override
  String get libraryResetConfirmTitle => '¿Reiniciar la biblioteca?';

  @override
  String get libraryResetConfirmBody =>
      'Se eliminarán todos los libros, capítulos y recetas. Esta acción no se puede deshacer. ¿Continuar?';

  @override
  String get libraryResetDone =>
      'Biblioteca reiniciada. Ya puedes importar tus recetarios.';

  @override
  String get errorTitle => 'Error';

  @override
  String get connectingBackend => 'Iniciando la aplicación…';

  @override
  String get backendFailed =>
      'No se ha podido iniciar el servicio de datos. Vuelve a abrir la aplicación.';

  @override
  String get loading => 'Cargando…';

  @override
  String get retry => 'Reintentar';
}

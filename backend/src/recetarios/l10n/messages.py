"""Spanish user-facing messages. Codes are stable English keys (constitution VI)."""

MESSAGES: dict[str, str] = {
    "not_found": "No se ha encontrado el elemento solicitado.",
    "book_not_found": "No se ha encontrado el libro.",
    "chapter_not_found": "No se ha encontrado el capítulo.",
    "recipe_not_found": "No se ha encontrado la receta.",
    "image_not_found": "No se ha encontrado la imagen.",
    "invalid_title": "El título no puede estar vacío ni superar 200 caracteres.",
    "invalid_image_ref": "El contenido hace referencia a una imagen que no existe.",
    "invalid_image_data": "El archivo no es una imagen válida.",
    "invalid_parent_chapter": "El capítulo padre no es válido.",
    "invalid_order": "La nueva ordenación no es válida: debe incluir todos los elementos.",
    "validation_error": "Los datos enviados no son válidos.",
    "legacy_file_not_found": "No se ha encontrado el archivo de recetario antiguo.",
    "legacy_invalid_format": "El archivo no tiene el formato de recetario antiguo esperado.",
    "archive_invalid": "El archivo de biblioteca no es válido o está dañado.",
    "archive_confirm_required": (
        "La importación reemplaza toda la biblioteca y requiere confirmación."
    ),
    "output_dir_invalid": "La carpeta de destino no existe o no se puede escribir en ella.",
    "pdf_job_not_found": "No se ha encontrado la tarea de generación de PDF.",
    "internal_error": "Se ha producido un error inesperado.",
}


def msg(code: str) -> str:
    return MESSAGES.get(code, MESSAGES["internal_error"])

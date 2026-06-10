# Feature Specification: Recipe Management (Recetarios-Mama)

**Feature Branch**: `001-recipe-management`

**Created**: 2026-06-03

**Status**: Draft

**Input**: User description: "A desktop and mobile application to create, import, view, update and delete cooking recipes... presented in Spanish..."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Book Management & Initial Navigation (Priority: P1)

As a user, I want to see my recipe books and be able to create new ones to organize my collections from the start.

**Why this priority**: This is the entry point of the application. Without books, there is no structure for chapters or recipes.

**Independent Test**: Can be verified by opening the app, seeing the book list (or the add button if empty), and successfully creating a book.

**Acceptance Scenarios**:

1. **Given** the application opens for the first time, **When** there is no data, **Then** the "Add Book" button is displayed.
2. **Given** the book list, **When** a title or description is too long, **Then** an ellipsis (...) is shown to maintain a clean design.
3. **Given** the creation form, **When** a new book is saved with a title, image, and description, **Then** it appears on the main screen.

---

### User Story 2 - Chapter Structure (Priority: P2)

As a user, I want to organize my books into chapters to classify my recipes (e.g., Starters, Desserts).

**Why this priority**: It allows for a logical intermediate organization before reaching individual recipes.

**Independent Test**: Select an existing book, view the chapter list, and successfully add a new one.

**Acceptance Scenarios**:

1. **Given** a selected book, **When** its content is viewed, **Then** the chapter list is displayed with its image and initial description.
2. **Given** the chapter view, **When** the add button is pressed, **Then** a form opens to create a new chapter.

---

### User Story 3 - Recipe Management & Visualization (Priority: P1)

As a user, I want to view, create, and edit individual recipes, including ingredients and preparation steps with images.

**Why this priority**: This is the functional core of the application.

**Independent Test**: Create a complete recipe, save it, view it in read mode, and then enable edit mode to modify it.

**Acceptance Scenarios**:

1. **Given** a selected chapter, **When** the recipe list is shown, **Then** the user can toggle between "Detailed View" (image+description) and "Titles Only" using a toggle button.
2. **Given** a recipe opened in read mode, **When** the edit button is pressed, **Then** the rich text editors and the ingredient list editor are enabled.
3. **Given** edit mode, **When** the user makes changes and presses "Save", **Then** the changes are persisted; if "Discard" is pressed, the recipe reverts to its previous state.

---

### User Story 4 - Data Import & Export (Priority: P3)

As a user, I want to import my old JSON data and export my entire current library for backup purposes.

**Why this priority**: Facilitates migration from previous systems and ensures data portability.

**Independent Test**: Import an old-format JSON file and verify that it correctly converts to books/chapters/recipes in the new app.

**Acceptance Scenarios**:

1. **Given** an old-format JSON file (Book with chapters), **When** it is imported into the application, **Then** the data is adapted to the new format and appears in the interface.
2. **Given** the export option, **When** the user exports the library, **Then** a single file containing all books, chapters, and recipes is generated.

---

### User Story 5 - PDF Generation (Books & Recipes) (Priority: P2)

As a user, I want to print my recipes or full books as PDFs for sharing or physical use.

**Why this priority**: Key requirement for offline utility and kitchen use.

**Independent Test**: Generate a PDF of a recipe and a PDF of a full book, verifying the structure (cover, index, etc.).

**Acceptance Scenarios**:

1. **Given** a recipe view, **When** print is pressed, **Then** the user can choose to include/exclude introduction and images before generating the PDF.
2. **Given** PDF generation, **When** the process completes, **Then** the file is saved in the configured folder and the OS is requested to open the file.
3. **Given** a full book, **When** it is exported to PDF, **Then** the resulting document includes a cover, index, chapter introduction pages, and a mandatory page break for each recipe.

### Edge Cases

- **Failed Import**: How the system reacts if the import JSON is corrupt or has an unexpected format.
- **Local Storage Full**: Behavior when there is no space to save new images or export PDFs.
- **Print Cancellation**: Ensure that if the user cancels the folder selection or options dialog, no errors or orphaned temporary files are produced.
- **Non-existent File Paths**: If the default PDF folder no longer exists, the system must prompt for a new location.
## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST show a progressive interface adaptable to any screen size (Mobile and Desktop).
- **FR-002**: The system MUST allow Create, Read, Update, and Delete (CRUD) operations for Books, Chapters, and Recipes.
  - **FR-002.1**: Titles for Books must be unique globally.
  - **FR-002.2**: Titles for Chapters must be unique within their parent Book.
  - **FR-002.3**: Titles for Recipes must be unique within their parent Chapter.
- **FR-003**: Recipes MUST support a structure of: Title, Introduction (Markdown rich text + images), Ingredient List, and Preparation Guide (Markdown rich text + images + layout options like grid).
...
## Clarifications

### Session 2026-06-09
- Q: Title Uniqueness → A: Titles must be unique within their parent container (e.g., recipes in a chapter).
- Q: Image Portability → A: Export is a self-contained archive with embedded images.
- Q: Data Persistence → A: Data is stored in a local structured database (SQLite/IndexedDB).
- Q: Rich Text Format → A: Markdown is used for rich text sections.

## User Scenarios & Testing *(mandatory)*
- **FR-005**: The system MUST support importing a previous JSON format (Book + Chapters) adapting it to the new model.
- **FR-006**: The system MUST allow exporting the entire database into a single importable file.
  - **FR-006.1**: The export file MUST be a self-contained archive (e.g., ZIP or JSON with base64) containing all text and images.
- **FR-007**: The system MUST generate PDF documents for individual recipes with customization options (include/exclude intro/images).
- **FR-008**: The system MUST generate PDF documents for full books including: Cover, Index, Chapter Introduction pages, and mandatory page breaks for each recipe.
- **FR-009**: The system MUST allow configuring a default folder for saving generated PDFs.
- **FR-010**: The system UI MUST be entirely in Spanish.
- **FR-011**: Text data MUST always be stored in UTF-8 format.
- **FR-012**: The system MUST NOT require login or user management.

### Key Entities *(include if feature involves data)*

- **Book**: Root entity. Contains title, cover image, description, and a collection of Chapters.
- **Chapter**: Intermediate organization. Contains title, image, description, and a collection of Recipes.
- **Recipe**: Detail entity. Contains title, introduction (text/images), ingredient list, and preparation steps (text/images/layout).
- **Settings**: Stores the default path for PDF exports and other local preferences.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can create a complete recipe (with ingredients and steps) in under 5 minutes.
- **SC-002**: Importing a 50-recipe JSON book completes in under 10 seconds on standard hardware.
- **SC-003**: The interface responds and adapts to resolution changes in under 200ms without loss of functionality.
- **SC-004**: Generated PDFs maintain visual integrity and UTF-8 format (Spanish special characters) in all standard viewers.
- **SC-005**: 100% of the UI and system messages are correctly localized to Spanish.

## Assumptions

- It is assumed the user has write permissions in the selected export folder.
- It is assumed the old JSON format is structurally predictable (even if it requires adaptation).
- The operating system has a default application to open PDF files.
- Images will be managed locally (possibly copied to an internal app folder to avoid broken links).

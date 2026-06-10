# Feature Specification: Recipe Management

**Feature Branch**: `002-recipe-management`

**Created**: 2026-06-10

**Status**: Draft

**Input**: User description: "A desktop and mobile application that will allow to create, import, view, update and delete cooking recipes. The application GUI will be progressive, allowing display on any reasonable screen size and proportions within PC and mobile worlds. The recipes will be organized in books and chapters, all of which may have a text and image presentation content. The application will allow the user to export each book as a PDF document for print. This PDF will include a cover page, an index, chapter introduction pages and all the recipes from the book, where each recipe always begins in a new page. Recipes will consist of a title, a list of ingredients and a preparation guide that may include text and images, allowing certain layout options such as a grid. The application will allow to import recipe data from a previously existing JSON format, where a JSON document will represent a whole book with chapters. Legacy data is stored under project root in a directory named 'legacy'. There is a JSON schema detailing the data format at [root]/legacy/schema. In this directory there is also an XML sample document with an analog format, which contains self explanatory data in spanish. The legacy data images are at [root]/legacy/imgs, and the legacy documents at [root]/legacy have image links relative to the root, so all images are defined as paths that start by ./imgs or similar. The importing of this old format will adapt the contents to the new format of the application. Data for the application will be stored locally and it should be possible to export it into a single file containing all the books, chapters and recipes in a way that the application will be able to import. The application will not handle user login. Once opened, it will display all available books, showing the book title, with the image if present, and the initial book description (which, if too long, may be shortened by an ellipsis '...'). The book selection list will include a button to add a new book, which will bring the user to a book creation form. Once the user selects a book, the chapter list will display, where chapters will show the same information as the books in the previous screen (title, image if present, initial description). The chapter selection list will include a button to add a new chapter, which will bring the user to a chapter creation form. Once an existing chapter is selected, a recipe list will display. Initially, recipes will display in a similar way to the books and chapters, with title, image and description. But the application will display a button to allow the user to show only the titles for ease of browsing. This button will be a toggle type control, to switch between the display modes. Once a recipe is selected, it will be displayed with the introductory text and images first, then the ingredients list and finally the preparation guide. The recipe view will display in view mode initially, but a button will enable the user to toggle into edit mode, where it will be possible to modify any element of the recipe. When in edit mode, 'save' and 'discard changes' button will display to allow the user to either save the work or discard it. When editing a recipe, each section will have the appropiate input types for each section, i.e. a rich text editor for introduction and preparation guide that allows image insertion and positioning, and a list editor for the ingredients list. The recipe view will also show a print button. This button will present the user with a choice to include or skip the introduction and or the images. According to this choice, and unless the operation is cancelled, the application will generate a PDF file containing the recipe that may or may not include images and introduction according to the previous choice. Once generated, the application will save the PDF file in a user selectable folder (which will default to the user folder as a preset that may be configured persistently by the user in a configuration menu). Then the application will signal the operating system to open the resulting PDF file. The application will be presented in the spanish language and text data will be always stored in the UTF-8 format. However, all of the project documentation and coding will use english exclusively."

## Clarifications

### Session 2026-06-10

- Q: How should nested legacy chapters (chapters inside chapters) be handled? → A: The application supports nested chapters (subchapters) natively; the legacy hierarchy is preserved on import.
- Q: What happens when importing a full library backup into an application that already has content? → A: The import replaces the entire library after an explicit confirmation (restore semantics).
- Q: What happens when importing a legacy JSON book whose title matches an existing book? → A: The application asks the user whether to replace the existing book or keep both.
- Q: Can users control the order of chapters and recipes (which drives the printed book sequence)? → A: Yes — manual reordering of chapters within their parent and recipes within their chapter; new items append at the end; imports preserve source order.
- Q: Is recipe search in scope for this feature? → A: Yes, full-text search: titles, ingredients, preparation, and introduction text across all books.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Book Browsing & Management (Priority: P1)

As a home cook, when I open the application I want to see all my recipe books at a glance — each with its title, cover image, and a short description — and be able to create new books, so that I can organize my recipe collection from the very first screen without any login step.

**Why this priority**: Books are the root entity of the whole system. Every other capability (chapters, recipes, import, PDF export) depends on books existing and being reachable from the home screen. This story alone delivers a usable, demonstrable product slice.

**Independent Test**: Launch the application, observe the book list (title, image if present, truncated description), create a new book through the "add book" form, and verify it appears in the list. Resize the window from phone-sized to desktop-sized and verify the layout remains usable.

**Acceptance Scenarios**:

1. **Given** the application starts, **When** the home screen loads, **Then** all available books are displayed showing title, cover image (when present), and the initial part of the description, with no login or user selection step.
2. **Given** a book whose description is longer than the available display space, **When** it is rendered in the book list, **Then** the visible text is shortened and ends with an ellipsis ("...").
3. **Given** the book list, **When** the user activates the "add book" button, **Then** a book creation form opens where title, presentation text, and image can be defined, and saving it adds the new book to the list.
4. **Given** any reasonable screen size or aspect ratio (desktop monitor, laptop, tablet, phone, portrait or landscape), **When** the book list is displayed or the viewport is resized, **Then** the layout adapts progressively and remains readable and operable.
5. **Given** an existing book, **When** the user edits its presentation data or deletes it, **Then** the changes are persisted locally and reflected in the list.

---

### User Story 2 - Chapter Browsing & Management (Priority: P2)

As a home cook, after selecting a book I want to see its chapters presented the same way as books (title, image, short description) and be able to add new chapters, so that I can structure each book into meaningful sections.

**Why this priority**: Chapters are the organizational layer between books and recipes. They are required before recipes can be placed anywhere, and they reuse the listing/creation interaction pattern established in User Story 1.

**Independent Test**: Select an existing book, observe the chapter list, create a new chapter through the "add chapter" form, and verify it appears in the chapter list of that book only.

**Acceptance Scenarios**:

1. **Given** a selected book, **When** its detail opens, **Then** the list of its chapters is displayed showing title, image (when present), and initial description with ellipsis truncation when too long.
2. **Given** the chapter list, **When** the user activates the "add chapter" button, **Then** a chapter creation form opens and saving it adds the chapter to the current book.
3. **Given** a chapter with presentation content (text and images), **When** the user opens the chapter for editing, **Then** the presentation content can be modified and persisted.
4. **Given** a book with no chapters yet, **When** the book is opened, **Then** an understandable empty state is shown together with the "add chapter" action.
5. **Given** a chapter containing subchapters, **When** the chapter opens, **Then** its subchapters are listed with the same presentation pattern (title, image, truncated description) before or alongside its recipes, and selecting a subchapter navigates into it.
6. **Given** any chapter list (top level or nested), **When** the user activates the "add chapter" action, **Then** the new chapter is created at the current nesting level.

---

### User Story 3 - Recipe Browsing & Viewing (Priority: P3)

As a home cook, after selecting a chapter I want to browse its recipes — either as detailed cards or as a compact title-only list — and open any recipe to read its introduction, ingredients, and preparation guide in that order, so that I can find and follow a recipe comfortably while cooking.

**Why this priority**: Reading recipes is the core daily value of the application. It depends on books and chapters existing, hence P3, but together with stories 1–2 it completes the full browsing journey.

**Independent Test**: Select a chapter containing recipes, toggle between detailed and title-only display modes, open a recipe, and verify the section order (introduction → ingredients → preparation) in view mode.

**Acceptance Scenarios**:

1. **Given** a selected chapter, **When** its recipe list opens, **Then** recipes are displayed with title, image (when present), and initial description, like books and chapters.
2. **Given** the recipe list, **When** the user activates the display-mode toggle, **Then** the list switches to a titles-only presentation, and activating it again returns to the detailed presentation.
3. **Given** a recipe is selected, **When** the recipe view opens, **Then** the introductory text and images are shown first, followed by the ingredients list, and finally the preparation guide.
4. **Given** a recipe with grouped ingredients (e.g., "For the sauce"), **When** the recipe is viewed, **Then** each ingredient group is shown with its heading and the servings indication is visible when defined.
5. **Given** the recipe view, **When** it first opens, **Then** it is in read-only view mode.

---

### User Story 4 - Recipe Creation & Editing (Priority: P4)

As a home cook, I want to create new recipes and edit any element of an existing recipe — introduction, ingredients, preparation guide, images, and layout — with editors appropriate to each section, so that I can grow and maintain my collection.

**Why this priority**: Editing turns the application from a reader into a manager. It builds on the recipe view (P3) by adding the edit mode, and is required before the collection can grow beyond imported content.

**Independent Test**: Open a recipe, switch to edit mode, modify the title, an ingredient, and a preparation paragraph, insert an image, save, reload the recipe, and verify all changes persisted. Repeat making changes and discarding them, verifying nothing changed.

**Acceptance Scenarios**:

1. **Given** a recipe in view mode, **When** the user activates the edit toggle, **Then** the view switches to edit mode and "save" and "discard changes" buttons appear.
2. **Given** a recipe in edit mode with modifications, **When** the user activates "save", **Then** all changes are persisted locally and the view returns to read-only mode showing the updated content.
3. **Given** a recipe in edit mode with modifications, **When** the user activates "discard changes", **Then** all modifications are abandoned and the recipe displays its previously saved state.
4. **Given** edit mode, **When** the user edits the introduction or the preparation guide, **Then** a rich text editor is available that allows inserting and positioning images within the text, including layout options such as a grid arrangement.
5. **Given** edit mode, **When** the user edits the ingredients, **Then** a list editor is available that supports adding, removing, reordering, and grouping ingredient entries, and setting the servings count.
6. **Given** the recipe list of a chapter, **When** the user activates the "add recipe" action, **Then** a new recipe can be created in that chapter with title, introduction, ingredients, and preparation guide.

---

### User Story 5 - Legacy Data Import (Priority: P5)

As the owner of an existing recipe collection in the legacy JSON format, I want to import a legacy JSON document (one document = one whole book with chapters and recipes) and have its content adapted to the application format, including its images, so that decades of family recipes become available in the new application without retyping.

**Why this priority**: The real-world collection already exists in the legacy format; importing it is the fastest way to fill the application with meaningful content. It depends on the data structures of stories 1–4 being in place.

**Independent Test**: Import one of the legacy JSON files from the `legacy` directory and verify a complete book appears with its chapters, recipes, ingredient groups, introduction texts, tables, and images correctly displayed.

**Acceptance Scenarios**:

1. **Given** a legacy JSON document conforming to the legacy schema, **When** the user imports it, **Then** a new book is created with its title, introduction, chapters, and recipes adapted to the application format.
2. **Given** legacy content referencing images by relative paths (starting with `./imgs` or similar), **When** the document is imported, **Then** the referenced image files are located relative to the legacy document location, incorporated into the application's local storage, and displayed correctly afterwards.
3. **Given** legacy recipes containing grouped ingredients with optional group titles and a servings attribute, **When** imported, **Then** groups, group titles, and servings are preserved.
4. **Given** legacy introductions containing paragraphs, titled sections, single images with captions, image collections, and tables, **When** imported, **Then** this content is preserved in the book or chapter presentation content.
5. **Given** a legacy document containing nested chapters (chapters inside chapters), **When** imported, **Then** the chapter hierarchy is preserved as nested chapters in the application without losing any recipe or introduction content.
6. **Given** a malformed legacy document or one referencing missing image files, **When** the import runs, **Then** the user receives a clear message describing the problem, the import of valid content does not silently corrupt existing data, and missing images are reported without aborting the whole import.

---

### User Story 6 - Book Export to PDF (Priority: P6)

As a home cook, I want to export a whole book as a print-ready PDF document — with a cover page, an index, chapter introduction pages, and every recipe starting on a new page — so that I can print a physical copy of a recipe book.

**Why this priority**: Producing a printable book is a headline goal of the project (a printed family recipe book), but it requires complete book content to be valuable, so it follows content management and import.

**Independent Test**: Export a book containing several chapters and recipes and verify the resulting PDF contains, in order: a cover page, an index, each chapter's introduction page(s), and all recipes, each beginning on a new page.

**Acceptance Scenarios**:

1. **Given** a book with chapters and recipes, **When** the user requests the book PDF export, **Then** a single PDF document is generated containing a cover page, an index, chapter introduction pages, and all the recipes of the book.
2. **Given** the generated book PDF, **When** inspecting recipe placement, **Then** every recipe begins at the top of a new page.
3. **Given** the generated book PDF, **When** inspecting the index, **Then** it reflects the book's chapters and recipes with their page locations, with subchapters indented under their parent chapter.
4. **Given** book content with images, tables, and grouped ingredients, **When** exported, **Then** the PDF reproduces them legibly in a layout suitable for print.

---

### User Story 7 - Single Recipe Print to PDF (Priority: P7)

As a home cook, I want to print an individual recipe to PDF, choosing whether to include the introduction and/or the images, and have the resulting file saved to my preferred folder and opened automatically, so that I can quickly produce a working copy for the kitchen.

**Why this priority**: A convenience feature layered on top of recipe viewing and PDF generation; valuable day to day but narrower in scope than the full book export.

**Independent Test**: From a recipe view, activate the print button, choose to skip images, confirm, and verify a PDF without images is created in the configured folder and opened by the operating system. Repeat with cancellation and verify no file is produced.

**Acceptance Scenarios**:

1. **Given** the recipe view, **When** the user activates the print button, **Then** a dialog offers choices to include or skip the introduction and to include or skip the images, plus the option to cancel.
2. **Given** the print dialog, **When** the user confirms a combination of choices, **Then** a PDF of the recipe is generated honoring those choices.
3. **Given** the print dialog, **When** the user cancels, **Then** no PDF is generated and no file is written.
4. **Given** a generated recipe PDF, **When** the generation finishes, **Then** the file is saved into the user-selectable destination folder (defaulting to the configured preset) and the application signals the operating system to open it.
5. **Given** the configuration menu, **When** the user changes the default PDF destination folder, **Then** the new value persists across application restarts.

---

### User Story 8 - Full Library Backup & Restore (Priority: P8)

As a cautious user, I want to export my entire library (all books, chapters, recipes, and their images) into a single file and import such a file back into the application, so that I can back up my collection or move it to another device.

**Why this priority**: Data safety and portability matter for a local-only application, but the feature only becomes meaningful once content exists; it closes the data lifecycle.

**Independent Test**: Export the full library to a single file, reset or use a fresh installation, import the file, and verify all books, chapters, recipes, and images are restored identically.

**Acceptance Scenarios**:

1. **Given** a library with content, **When** the user requests a full export, **Then** a single file is produced containing all books, chapters, recipes, and the data needed to restore them, including images.
2. **Given** a previously exported library file, **When** the user imports it, **Then** the application restores the books, chapters, and recipes so that they are equivalent to the originals.
3. **Given** an import of a library file into an application that already has content, **When** the import is requested, **Then** the application warns that the current library will be completely replaced and proceeds only after explicit confirmation; cancelling leaves existing content untouched.

---

### User Story 9 - Full-Text Recipe Search (Priority: P9)

As a home cook with hundreds of imported recipes, I want to search across all my books by any text — a recipe title, an ingredient, or words from the preparation or introduction — and jump straight to a matching recipe, so that I can find "that recipe with chanterelles" without remembering which book or chapter holds it.

**Why this priority**: Search multiplies the value of a large imported library, but it operates over content created by the previous stories, so it lands after the data lifecycle is complete.

**Independent Test**: With an imported library, search for a word that appears only in one recipe's ingredients, verify that recipe is found with its book/chapter context shown, and that selecting the result opens the recipe view.

**Acceptance Scenarios**:

1. **Given** a library with content, **When** the user enters a search text, **Then** all recipes whose title, ingredients, preparation guide, or introduction contain the text are listed, each showing its title and its book/chapter location.
2. **Given** search results, **When** the user selects a result, **Then** the corresponding recipe opens in view mode.
3. **Given** a search query with or without accents (e.g., "champinon" vs "champiñón"), **When** the search runs, **Then** matching is accent-insensitive and case-insensitive.
4. **Given** a query with no matches, **When** the search runs, **Then** an understandable empty state is shown in Spanish.

---

### Edge Cases

- A book, chapter, or recipe has no image: lists must render correctly without a placeholder gap that breaks the layout.
- Description text is empty or extremely long: truncation with ellipsis must work in both extremes.
- A chapter contains no recipes, or a book contains no chapters: empty states with the corresponding "add" action must be displayed.
- The user toggles to edit mode and navigates away with unsaved changes: the application must ask for confirmation before losing modifications.
- Legacy import: the JSON document does not conform to the schema or references image files that do not exist — each case must produce a clear, non-destructive outcome; a title collision with an existing book triggers the replace-or-keep-both choice.
- Legacy import: documents contain nested chapters (preserved as subchapters) or recipes attached directly to the book root (placed in an auto-created chapter); content must be adapted without loss.
- Text in any field contains accented characters, "ñ", or other non-ASCII characters: storage, display, and PDF output must preserve them (UTF-8 everywhere).
- The configured PDF destination folder no longer exists or is not writable: the user must be informed and offered to pick another folder; the operation must not fail silently.
- PDF generation is requested for a very large book (hundreds of recipes, many images): generation must complete and the user must see progress or at least a busy indication.
- The device storage is full or the local data store cannot be written: the user must receive an understandable error and no data corruption may occur.
- A second application window or instance, if the platform allows it, must not corrupt the local data.

## Requirements *(mandatory)*

### Functional Requirements

#### General & Platform

- **FR-001**: The application MUST run as a desktop and mobile application whose interface adapts progressively to any reasonable screen size and aspect ratio in the PC and mobile worlds.
- **FR-002**: The application MUST NOT require user login or account management; opening the application leads directly to the book list.
- **FR-003**: All user interface text and user-facing messages MUST be presented in Spanish.
- **FR-004**: All stored text data MUST be encoded in UTF-8.
- **FR-005**: All application data MUST be stored locally on the user's device; no network service is required for any feature.

#### Books

- **FR-006**: The application MUST display, on start, the list of all available books showing each book's title, image (when present), and the initial portion of its description, truncated with an ellipsis ("...") when too long.
- **FR-007**: The book list MUST include an "add book" button that opens a book creation form.
- **FR-008**: Users MUST be able to create, view, update, and delete books, where each book has a title and optional presentation content composed of text and images.

#### Chapters

- **FR-009**: Selecting a book MUST display the list of its chapters, presented with the same information pattern as books (title, image when present, truncated initial description).
- **FR-010**: The chapter list MUST include an "add chapter" button that opens a chapter creation form.
- **FR-011**: Users MUST be able to create, view, update, and delete chapters within a book, where each chapter has a title and optional presentation content composed of text and images.
- **FR-011a**: Chapters MUST be nestable: a chapter MAY contain subchapters in addition to recipes, and chapter lists at any nesting level MUST present and behave the same way as the top-level chapter list.
- **FR-011b**: Users MUST be able to manually reorder chapters within their parent (book or chapter) and recipes within their chapter; newly created items are appended at the end, imported content preserves its source order, and lists, navigation, and PDF output MUST follow this order.

#### Recipe Browsing & Viewing

- **FR-012**: Selecting a chapter MUST display the list of its recipes, initially presented with title, image (when present), and truncated initial description.
- **FR-013**: The recipe list MUST provide a toggle control that switches between the detailed presentation and a titles-only presentation for ease of browsing.
- **FR-014**: Selecting a recipe MUST display it in read-only view mode with this section order: introductory text and images first, then the ingredients list, and finally the preparation guide.
- **FR-015**: A recipe MUST consist of a title, an ingredients list, and a preparation guide; the introduction and preparation guide may contain text and images with layout options such as a grid arrangement.
- **FR-016**: The ingredients list MUST support plain entries and grouped entries, where each group may have a heading (e.g., "For the dressing"), and the recipe may declare a servings indication.

#### Recipe Editing

- **FR-017**: The recipe view MUST provide a control to toggle into edit mode, where every element of the recipe (title, introduction, ingredients, preparation guide, images) can be modified.
- **FR-018**: In edit mode, the application MUST display "save" and "discard changes" buttons; saving persists all modifications and discarding restores the last saved state.
- **FR-019**: Each recipe section MUST be edited with an input type appropriate to it: a rich text editor for the introduction and the preparation guide that allows inserting and positioning images (including grid layout options), and a list editor for the ingredients.
- **FR-020**: Users MUST be able to create new recipes within a chapter and delete existing recipes.
- **FR-021**: The application MUST warn the user before unsaved recipe modifications would be lost (e.g., when navigating away from edit mode).

#### Legacy Import

- **FR-022**: The application MUST allow importing a legacy JSON document, where one document represents one whole book with its chapters and recipes, adapting all content to the application's format.
- **FR-022a**: When the imported legacy book's title matches an existing book, the application MUST ask the user whether to replace the existing book or keep both; replacement requires explicit confirmation and cancelling leaves the library unchanged.
- **FR-023**: The import MUST resolve image references expressed as paths relative to the legacy document location (e.g., starting with `./imgs`), incorporate the image files into the application's local storage, and rewire the content to the incorporated copies.
- **FR-024**: The import MUST preserve the legacy content structures: book/chapter introductions (titled sections, paragraphs, single images with captions, image collections, and tables), recipes with image, grouped ingredients with optional group titles, servings indication, preparation paragraphs, and recipe notes.
- **FR-025**: The import MUST preserve the legacy chapter hierarchy, mapping nested legacy chapters to nested application chapters; recipes hanging directly from the book root are placed in an automatically created chapter, without losing content.
- **FR-026**: When an import fails or is partial (malformed document, missing image files), the application MUST report the problem clearly in Spanish and MUST NOT corrupt or partially overwrite existing data.

#### Library Export & Import

- **FR-027**: The application MUST be able to export the entire library (all books, chapters, recipes, and their images) into a single file.
- **FR-028**: The application MUST be able to import a library file produced by FR-027, restoring books, chapters, recipes, and images to an equivalent state. The import replaces the entire existing library and MUST require explicit user confirmation before doing so; a failed or cancelled import MUST leave the existing library unchanged.

#### PDF Generation

- **FR-029**: The application MUST be able to export any book as a PDF document for print, containing in order: a cover page, an index, chapter introduction pages, and all the recipes of the book.
- **FR-030**: In the book PDF, every recipe MUST begin on a new page.
- **FR-031**: The recipe view MUST include a print button that offers the user the choice to include or skip the introduction and/or the images, as well as the possibility to cancel the operation.
- **FR-032**: Unless cancelled, the application MUST generate a PDF of the recipe honoring the user's include/skip choices.
- **FR-033**: Generated PDFs MUST be saved into a user-selectable destination folder, whose preset default is the user's folder and which can be changed persistently in a configuration menu.
- **FR-034**: After generating a PDF, the application MUST signal the operating system to open the resulting file.

#### Configuration

- **FR-035**: The application MUST provide a configuration menu where persistent preferences — at minimum the default PDF destination folder — can be viewed and changed, and these preferences MUST survive application restarts.

#### Search

- **FR-036**: The application MUST provide a full-text search over all books that matches against recipe titles, ingredient entries, preparation guide text, and introduction text.
- **FR-037**: Search matching MUST be case-insensitive and accent-insensitive (e.g., "champinon" finds "champiñón").
- **FR-038**: Search results MUST show each matching recipe's title and its book/chapter location, and selecting a result MUST open that recipe in view mode.

### Key Entities

- **Book**: The top-level collection. Has a title and optional presentation content (text and images, where the first text serves as the description shown in lists). Contains an ordered set of chapters.
- **Chapter**: A section of a book. Has a title and optional presentation content like the book's. Contains an ordered set of recipes and may contain an ordered set of subchapters (nested chapters). Belongs to exactly one book, either directly or through its parent chapter.
- **Recipe**: The core content unit. Has a title, an optional image, an optional introduction (rich content), an ingredients list, a preparation guide (rich content), and an optional note. Belongs to exactly one chapter.
- **Ingredients List**: An ordered collection of ingredient groups belonging to a recipe, with an optional servings indication. Each group has an optional heading and an ordered list of ingredient entries (free text).
- **Presentation Content**: Rich content used by book/chapter introductions and recipe introduction/preparation sections. Composed of blocks: titled sections, paragraphs, images with optional captions, image collections, tables (header plus rows, cells holding text or an image with caption), and layout hints such as grid arrangement.
- **Library Archive**: A single self-contained file representing the full library (all books with their chapters, recipes, and images) for backup, transfer, and re-import.
- **Application Settings**: Persistent user preferences, including the default destination folder for generated PDFs.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can open the application and reach any recipe of an existing book with one interaction per navigation level (book → chapter → [subchapters →] recipe), with no login step — 4 interactions or fewer for recipes in top-level chapters.
- **SC-002**: The complete real legacy collection (the three legacy JSON books) imports successfully with 100% of recipes, chapters, ingredient groups, and resolvable images preserved, and every unresolvable image reported.
- **SC-003**: A user can create a new book, a chapter, and a complete recipe (with ingredients and preparation) in under 10 minutes on first use, without external help.
- **SC-004**: The interface remains fully readable and operable on screens from small phones (around 4–5 inches) to large desktop monitors, in portrait and landscape, with no horizontal scrolling in list and reading views.
- **SC-005**: Exporting a book of up to 100 recipes with images produces a print-ready PDF — cover, index, chapter introductions, each recipe on a new page — in under 2 minutes on typical consumer hardware.
- **SC-006**: Printing a single recipe to PDF, from pressing the print button to the document opening, takes under 15 seconds including the include/skip choices.
- **SC-007**: A full library export followed by an import on a clean installation restores 100% of books, chapters, recipes, and images with no manual fixes.
- **SC-008**: All Spanish text, including accented characters and "ñ", displays correctly in every screen and in every generated PDF (zero character-corruption defects).
- **SC-009**: Recipe lists with at least 200 recipes in a chapter remain smooth to browse (no dropped-frame stutter while scrolling), and toggling between detailed and titles-only modes completes its re-render in under 100 ms.
- **SC-010**: 95% of edit sessions end with an explicit "save" or "discard changes" action and never lose data silently.
- **SC-011**: A full-text search over a library of 1,000 recipes returns its results in under 1 second.

## Assumptions

- **Single local user**: The application serves one user per device; there is no authentication, no user profiles, and no concurrent multi-user editing.
- **Offline-first**: All features work without network connectivity; nothing in the feature requires a remote service.
- **Legacy import source**: Imports take the legacy JSON format (per the schema at `legacy/schema/recetarios-schema.json`); the XML sample only documents the analog structure and is not itself an import source. Legacy JSON files are assumed to be UTF-8 encoded.
- **Nested chapter depth**: The legacy data nests chapters at most a few levels deep; the application supports arbitrary nesting but the UI and PDF index are optimized for up to 3 levels.
- **Recipes at the book root in legacy data**: If a legacy document holds recipes directly under the book (outside any chapter), an automatically created chapter (e.g., named after the book) hosts them.
- **Image handling on import**: Imported images are copied into the application's local storage so the library is self-contained; the original `legacy` directory is never modified.
- **Deletion semantics**: Deleting a book deletes its chapters and recipes; deleting a chapter deletes its recipes. A confirmation in Spanish is always requested before cascade deletion.
- **"User folder" default**: The default PDF destination preset is the operating system's standard user folder (or its Documents equivalent) for the current platform.
- **Description in lists**: The "initial description" shown in book/chapter/recipe lists is derived from the first text content of the item's presentation content.
- **PDF page size**: Print output targets a standard paper size (A4) suitable for home printing.
- **Language of artifacts**: Per the project constitution, all documentation and code are written in English while the UI is in Spanish.

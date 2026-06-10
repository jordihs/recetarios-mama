"""Shared accessors for per-app singletons stored on app.state."""

from fastapi import Request

from recetarios.services.library import LibraryService
from recetarios.storage.repository import Repository


def repository(request: Request) -> Repository:
    state = request.app.state
    if not hasattr(state, "repository"):
        state.repository = Repository(state.db)
    return state.repository


def library_service(request: Request) -> LibraryService:
    state = request.app.state
    if not hasattr(state, "library"):
        state.library = LibraryService(repository(request), state.images)
    return state.library

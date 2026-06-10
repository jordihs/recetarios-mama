"""Domain error type mapped to the API error envelope."""

from recetarios.l10n.messages import msg


class ApiError(Exception):
    def __init__(self, code: str, status: int = 400, detail: str | None = None):
        self.code = code
        self.status = status
        self.message = detail or msg(code)
        super().__init__(self.message)


class NotFoundError(ApiError):
    def __init__(self, code: str = "not_found"):
        super().__init__(code, status=404)

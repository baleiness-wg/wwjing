class BookmarkError extends Error {
  constructor(status, code, message, details) {
    super(message);
    this.name = "BookmarkError";
    this.status = status;
    this.code = code;
    this.details = details;
  }
}

module.exports = BookmarkError;

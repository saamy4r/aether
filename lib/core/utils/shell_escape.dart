/// Quotes [s] so a POSIX shell treats it as a single literal word.
///
/// Wraps in single quotes and escapes embedded single quotes as `'\''`,
/// which neutralizes `$`, backticks, `"`, `;`, newlines, etc.
String shQuote(String s) => "'${s.replaceAll("'", "'\\''")}'";

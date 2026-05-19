import Foundation

/// Debug-only print helper. Compiles to no-op in Release.
/// Use this instead of `print()` for diagnostic logs so production builds stay quiet.
@inlinable
func debugLog(_ items: Any...) {
    #if DEBUG
    let message = items.map { "\($0)" }.joined(separator: " ")
    print(message)
    #endif
}

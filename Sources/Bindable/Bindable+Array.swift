import Foundation
import SQLite3

extension Array: Expression where Self: Codable, Element: Bindable {
  public typealias ExpressionValue = Self

  public func append(to builder: inout SQLBuilder) {
    builder.sql.append("?")
    builder.binders.append(managedBinder)
  }
}

extension Array: Bindable where Self: Codable, Element: Bindable {}

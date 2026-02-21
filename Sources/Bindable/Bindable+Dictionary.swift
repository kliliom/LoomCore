import Foundation
import SQLite3

extension Dictionary: Expression where Self: Codable, Key: Bindable, Value: Bindable {
  public typealias ExpressionValue = Self

  public func append(to builder: inout SQLBuilder) {
    builder.appendLiteral("?")
    builder.appendBinder(managedBinder)
  }
}

extension Dictionary: Bindable where Self: Codable, Key: Bindable, Value: Bindable {}

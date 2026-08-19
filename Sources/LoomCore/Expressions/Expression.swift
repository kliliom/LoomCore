/// SQL expression that produces a typed value when evaluated by SQLite.
///
/// Expressions are the building blocks of the query DSL: columns, literals, operators,
/// function calls, and aggregates all conform to `Expression`. The associated
/// `ExpressionValue` type flows through the DSL so that comparisons, arithmetic, and
/// projections stay type-checked at compile time.
///
/// Every `Bindable` type is also an `Expression` of itself, which is what lets a
/// literal participate in expression building:
///
/// ```swift
/// let name = ColumnExpression<String>("name")
/// let age = ColumnExpression<Int>("age")
/// let predicate = (name == "Alice") && (age > 21)
///
/// var builder = SQLBuilder()
/// predicate.append(to: &builder)
/// // builder produces: ( ( "name" = ? ) AND ( "age" > ? ) )
/// ```
///
/// Conformers must be `Sendable` because expressions are used from `@DatabaseActor`
/// contexts and may be captured into binder closures.
public protocol Expression<ExpressionValue>: Sendable {
  /// Value type produced when this expression is evaluated.
  associatedtype ExpressionValue

  /// Writes this expression's SQL fragment into `builder`, registering any parameter
  /// binders required to supply its placeholder values.
  func append(to builder: inout SQLBuilder)
}

extension Expression {
  /// Wraps this expression as `any Expression<ExpressionValue>`.
  ///
  /// Useful when assembling heterogeneous collections of expressions that share a
  /// value type but differ in their concrete representation:
  ///
  /// ```swift
  /// let filters: [any LoomCore.Expression<Bool>] = [
  ///   (ColumnExpression<Int>("age") > 21).eraseToAnyExpression(),
  ///   ColumnExpression<Bool>("is_active").eraseToAnyExpression(),
  /// ]
  /// ```
  public func eraseToAnyExpression() -> any Expression<ExpressionValue> {
    self
  }
}

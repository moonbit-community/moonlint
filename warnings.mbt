///|
pub enum Warning {
  MatchTryQuestion(Location)
  StringLiteralMultiplyNumber(Location)
} derive(Show)

///|
priv struct LintEnv(Array[Warning])

///|
impl @syntax.IterVisitor for LintEnv with visit_Expr(env, expr) {
  if expr
    is Match(
      expr=Group(
        expr=TryOperator(kind=Question, body=_, try_loc=_, loc=_),
        group=Paren,
        loc=_
      ),
      cases=_,
      match_loc=_,
      using_=_,
      loc~
    ) {
    /// curresponding anti-pattern:
    /// 
    /// ```pesudo mbt code
    /// match (try? expr) {
    ///   Ok(value) => <branch_ok>
    ///   Err(err) => <branch_err>
    /// }
    /// ```
    /// 
    /// should be replaced with:
    /// 
    /// ```pesudo mbt code
    /// try expr catch {
    ///   err => <branch_err>
    /// } noraise {
    ///   value => <branch_ok>
    /// }
    /// ```
    env.0.push(Warning::MatchTryQuestion(loc))
  }
  if expr
    is Infix(
      op={ name: Ident(name="*"), .. },
      lhs=Constant(c=String(_), ..),
      rhs=_,
      loc~
    ) {
    /// curresponding anti-pattern:
    /// 
    /// ```pesudo mbt code
    /// "<string literal>" * n
    /// ```
    /// 
    /// if n was an integer expression, it should be replaced with:
    /// 
    /// ```pesudo mbt code
    /// "<string literal>".repeat(n)
    /// ```
    env.0.push(Warning::StringLiteralMultiplyNumber(loc))
  }
  env.base().visit_Expr(expr)
}

///|
pub fn lint(impls : Impls) -> Array[Warning] {
  let env = LintEnv(Array::new(capacity=40))
  for impl_ in impls {
    env.visit_Impl(impl_)
  } else {
    let LintEnv(warnings) = env
    warnings
  }
}

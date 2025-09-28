///|
pub enum Warning {
  MatchTryQuestion(Location)
  StringLiteralMultiplyNumber(Location)
} derive(Show)

///|
priv struct LintEnv(Array[Warning])

///|
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
/// let value = expr catch {
///   err => <branch_err>
/// }
/// <branch_ok>
/// ```
/// 
impl @syntax.IterVisitor for LintEnv with visit_Expr_Match(
  env,
  expr~,
  cases~,
  match_loc~,
  using_~,
  loc~,
) {
  ignore(match_loc)
  if expr is Group(expr=expr_inner, group=Paren, loc=group_loc) &&
    expr_inner is TryOperator(kind~, body~, try_loc~, loc=try_op_loc) &&
    kind is Question {
    ignore(group_loc)
    ignore(try_loc)
    ignore(try_op_loc)
    env.base().visit_Expr(body)
    env.0.push(Warning::MatchTryQuestion(loc))
  } else {
    env.base().visit_Expr(expr)
  }
  cases.each(env.base().visit_Case(_))
  match using_ {
    Some(using_) => env.base().visit_Label(using_)
    None => ()
  }
}

///|
/// curresponding anti-pattern:
/// 
/// ```pesudo mbt code
/// "<string literal>" * n
/// ```
/// 
/// should be replaced with:
/// 
/// ```pesudo mbt code
/// "<string literal>".repeat(n)
/// ```
/// 
impl @syntax.IterVisitor for LintEnv with visit_Expr(env, expr) {
  if expr
    is Infix(
      op={ name: Ident(name="*"), .. },
      lhs=Constant(c=String(_), ..),
      loc~,
      ..
    ) {
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

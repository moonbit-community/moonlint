///|
pub enum Warning {
  MatchTryQuestion(Location)
} derive(Show)

///|
priv struct LintEnv(Array[Warning])

///|
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
pub fn lint(impls : Impls) -> Array[Warning] {
  let env = LintEnv(Array::new(capacity=40))
  for impl_ in impls {
    env.visit_Impl(impl_)
  } else {
    let LintEnv(warnings) = env
    warnings
  }
}

///|
pub enum Warning {
  MatchTryQuestion(Location)
  StringLiteralMultiplyNumber(Location)
  CStyleForLoop(Location)
} derive(Show)

///|
priv struct LintEnv(Array[Warning])

///|
/// Check if the variable is only used in array[var] form,
/// and extract the array name
priv struct ArrayGetChecker {
  var_name : String
  mut array_name : String?
  mut is_valid : Bool
}

///|
impl @syntax.IterVisitor for ArrayGetChecker with visit_Expr(self, expr) {
  match expr {
    ArrayGet(
      array=Ident(id={ name: Ident(name~), .. }, ..),
      index=Ident(id=idx, ..),
      ..
    ) =>
      if idx.name is Ident(name=idx_name) && idx_name == self.var_name {
        // Found items[i] pattern
        match self.array_name {
          None => self.array_name = Some(name)
          Some(existing) =>
            if existing != name {
              // Different arrays used, not a simple iteration
              self.is_valid = false
            }
        }
        // Don't visit children - we've handled this usage
        return
      }
    Ident(id={ name: Ident(name~), .. }, ..) =>
      if name == self.var_name {
        // Variable used outside of array indexing
        self.is_valid = false
      }
    _ => ()
  }
  self.base().visit_Expr(expr)
}

///|
fn check_only_array_get_usage(
  var_name : String,
  expr : @syntax.Expr,
) -> String? {
  let checker = ArrayGetChecker::{ var_name, array_name: None, is_valid: true }
  checker.visit_Expr(expr)
  if checker.is_valid {
    checker.array_name
  } else {
    None
  }
}

///|
/// Check if the condition is in the form `i < array.length()` or `i < array.count()`
fn extract_array_from_condition(
  var_name : String,
  cond : @syntax.Expr,
) -> String? {
  match cond {
    Infix(
      op={ name: Ident(name="<"), .. },
      lhs=Ident(id={ name: Ident(name~), .. }, ..),
      rhs=DotApply(
        self=Ident(id={ name: Ident(name=array_name), .. }, ..),
        method_name={ name: method_name, .. },
        args=Empty,
        ..
      ),
      ..
    ) =>
      if name == var_name && (method_name == "length" || method_name == "count") {
        Some(array_name)
      } else {
        None
      }
    _ => None
  }
}

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
  // Check for C-style for loop that could be foreach
  // Pattern: for i = 0; i < items.length(); i = i + 1 { items[i] }
  if expr
    is For(
      binders=More((binder, Constant(c=Int(init_val), ..)), tail=Empty),
      condition=Some(condition),
      continue_block=More((cont_binder, _), tail=Empty),
      body~,
      loc~,
      ..
    ) {
    let var_name = binder.name
    // Check: init value is 0, and continue_block uses same variable
    if init_val == "0" && cont_binder.name == var_name {
      // Check if condition is `i < items.length()`
      if extract_array_from_condition(var_name, condition) is Some(cond_array) {
        // Check if variable is only used in items[i] form in the body
        if check_only_array_get_usage(var_name, body) is Some(body_array) {
          // Check if both reference the same array
          if cond_array == body_array {
            env.0.push(Warning::CStyleForLoop(loc))
          }
        }
      }
    }
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

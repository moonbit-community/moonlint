///|
pub enum Warning {
  MatchTryQuestion(Location)
  StringLiteralMultiplyNumber(Location)
  CStyleForLoop(Location)
  ConsecutivePrintln(Location)
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
/// Check if an expression is `println("<string literal>")` and return its location
fn is_println_string_literal(expr : @syntax.Expr) -> Location? {
  match expr {
    Apply(
      func=Ident(id={ name: Ident(name="println"), .. }, ..),
      args=More(
        { value: Constant(c=String(_), ..), kind: Positional },
        tail=Empty
      ),
      loc~,
      ..
    ) => Some(loc)
    _ => None
  }
}

///|
/// Find consecutive println string literal calls (3 or more)
/// Returns the location of the first println in the consecutive sequence, or None
fn find_consecutive_println(exprs : @list.List[@syntax.Expr]) -> Location? {
  find_consecutive_println_helper(exprs, None, 0)
}

///|
fn find_consecutive_println_helper(
  exprs : @list.List[@syntax.Expr],
  first_loc : Location?,
  count : Int,
) -> Location? {
  match exprs {
    More(expr, tail~) =>
      match is_println_string_literal(expr) {
        Some(loc) => {
          let new_first_loc = if first_loc is None {
            Some(loc)
          } else {
            first_loc
          }
          let new_count = count + 1
          if new_count >= 3 {
            // Found 3+ consecutive printlns, return the first location
            new_first_loc
          } else {
            find_consecutive_println_helper(tail, new_first_loc, new_count)
          }
        }
        None =>
          // Reset and continue searching
          find_consecutive_println_helper(tail, None, 0)
      }
    Empty =>
      // Reached end, check if we had 3+ consecutive
      if count >= 3 {
        first_loc
      } else {
        None
      }
  }
}

///|
/// Check trailing println including last_expr
fn check_trailing_println(
  env : LintEnv,
  exprs : @list.List[@syntax.Expr],
  last_expr : @syntax.Expr,
) -> Unit {
  // Only check if last_expr is a println
  if is_println_string_literal(last_expr) is None {
    return
  }
  // Count consecutive println from the end of exprs
  let count = count_trailing_println(exprs)
  // If we have 2+ trailing println in exprs + 1 from last_expr = 3+
  if count >= 2 {
    // Get the location of the first println in the trailing sequence
    if get_nth_from_end_println_loc(exprs, count) is Some(loc) {
      env.0.push(Warning::ConsecutivePrintln(loc))
    }
  }
}

///|
/// Count consecutive println from the end of the list
fn count_trailing_println(exprs : @list.List[@syntax.Expr]) -> Int {
  count_trailing_println_helper(exprs, 0)
}

///|
fn count_trailing_println_helper(
  exprs : @list.List[@syntax.Expr],
  acc : Int,
) -> Int {
  match exprs {
    More(expr, tail~) => {
      let tail_count = count_trailing_println_helper(tail, acc)
      // If we're at the end and all following are println, check this one
      if tail_count == list_length(tail) {
        if is_println_string_literal(expr) is Some(_) {
          tail_count + 1
        } else {
          0
        }
      } else {
        tail_count
      }
    }
    Empty => 0
  }
}

///|
fn list_length(exprs : @list.List[@syntax.Expr]) -> Int {
  match exprs {
    More(_, tail~) => 1 + list_length(tail)
    Empty => 0
  }
}

///|
/// Get the location of the Nth println from the end
fn get_nth_from_end_println_loc(
  exprs : @list.List[@syntax.Expr],
  n : Int,
) -> Location? {
  let len = list_length(exprs)
  get_nth_println_loc(exprs, len - n)
}

///|
fn get_nth_println_loc(
  exprs : @list.List[@syntax.Expr],
  index : Int,
) -> Location? {
  match exprs {
    More(expr, tail~) =>
      if index == 0 {
        is_println_string_literal(expr)
      } else {
        get_nth_println_loc(tail, index - 1)
      }
    Empty => None
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
  // Check for consecutive println string literals (3 or more)
  // Pattern: println("..."); println("..."); println("...")
  if expr is Sequence(exprs~, last_expr~, ..) {
    // Check the exprs list
    match find_consecutive_println(exprs) {
      Some(loc) => env.0.push(Warning::ConsecutivePrintln(loc))
      None =>
        // Only check trailing if we didn't find 3+ consecutive in exprs
        // This handles the case: println; println; <last_expr=println>
        check_trailing_println(env, exprs, last_expr)
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

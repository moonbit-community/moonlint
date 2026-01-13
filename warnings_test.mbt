///|
fn test_lint(source : String) -> Array[@moonlint.Warning] raise {
  let (impls, reports) = @parser.parse_string(source, name="<lint test>")
  if reports.length() > 0 {
    fail(reports.to_json().stringify(indent=2))
  }
  @moonlint.lint(impls)
}

///|
let match_try_question =
  #|fn main {
  #|  let foo = match (try? f()) {
  #|    Ok(_) => "ok"
  #|    Err(_) =>
  #|      match (try? f()) {
  #|        Ok(_) => "ok"
  #|        Err(_) => "failed"
  #|      }
  #|  }
  #|  println(foo)
  #|}

///|
test "match try?" {
  let warnings = test_lint(match_try_question)
  inspect(
    warnings,
    content="[MatchTryQuestion(<lint test>-2:13-9:4), MatchTryQuestion(<lint test>-5:7-8:8)]",
  )
}

///|
let string_literal_multiply_number =
  #|fn main {
  #|  let x = "hello" * 3
  #|}

///|
test "string literal multiply number" {
  let warnings = test_lint(string_literal_multiply_number)
  inspect(
    warnings,
    content="[StringLiteralMultiplyNumber(<lint test>-2:11-2:22)]",
  )
}

///|
let c_style_for_loop =
  #|fn main {
  #|  let items = [1, 2, 3]
  #|  for i = 0; i < items.length(); i = i + 1 {
  #|    println(items[i])
  #|  }
  #|}

///|
test "c style for loop" {
  let warnings = test_lint(c_style_for_loop)
  inspect(
    warnings,
    content="[CStyleForLoop(<lint test>-3:3-5:4)]",
  )
}

///|
let c_style_for_loop_ok =
  #|fn main {
  #|  let items = [1, 2, 3]
  #|  for i = 0; i < items.length(); i = i + 1 {
  #|    // i is used for something else too
  #|    println(items[i])
  #|    println(i)
  #|  }
  #|}

///|
test "c style for loop ok - multiple usages" {
  let warnings = test_lint(c_style_for_loop_ok)
  inspect(warnings, content="[]")
}

///|
let c_style_for_loop_ok_different_array =
  #|fn main {
  #|  let items = [1, 2, 3]
  #|  let other = [4, 5, 6]
  #|  for i = 0; i < items.length(); i = i + 1 {
  #|    // i is used with different arrays
  #|    println(items[i])
  #|    println(other[i])
  #|  }
  #|}

///|
test "c style for loop ok - different arrays" {
  let warnings = test_lint(c_style_for_loop_ok_different_array)
  inspect(warnings, content="[]")
}

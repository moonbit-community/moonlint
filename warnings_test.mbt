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
  #|  match (try? f()) {
  #|    Ok(_) => ()
  #|    Err(_) => ()
  #|  }
  #|}

///|
test "match try?" {
  let warnings = test_lint(match_try_question)
  inspect(warnings, content="[MatchTryQuestion(<lint test>-2:3-5:4)]")
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

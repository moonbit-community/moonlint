///|
fn read_mbt_file_to_impls(filename : String) -> @syntax.Impls raise {
  let source = @fs.read_file_to_string(filename)
  let (impls, reports) = @parser.parse_string(
    source,
    name=filename,
    parser=MoonYacc,
  )
  if reports.length() > 0 {
    fail(reports[0].to_string())
  }
  // println(impls.to_json().stringify(indent=2))
  return impls
}

///|
fn lint_file(filename : String) -> Array[@moonlint.Warning] raise {
  let impls = read_mbt_file_to_impls(filename)
  return @moonlint.lint(impls)
}

///|
fn report_antipattern(
  loc~ : @basic.Location,
  antipattern~ : String,
  suggestion~ : String,
  replace_condition? : String,
) -> String {
  let suggestion = if replace_condition is Some(replace_condition) {
    "If \{replace_condition}, \{suggestion}"
  } else {
    "\{suggestion}"
  }
  let msg =
    $| Found anti-pattern at \{loc}:
    $|
    $| \{antipattern}
    $|
    $| Suggestion: \{suggestion}
    $|
  return msg
}

///|
fn message_for_warning(warning : @moonlint.Warning) -> String {
  match warning {
    MatchTryQuestion(loc) => {
      let antipattern =
        #|     match (try? expr) {
        #|       Ok(value) => <branch_ok>
        #|       Err(err) => <branch_err>
        #|     }
      let suggestion =
        #|rewrite to:
        #|
        #|     try expr catch {
        #|       err => <branch_err>
        #|     } noraise {
        #|       value => <branch_ok>
        #|     }
      return report_antipattern(loc~, antipattern~, suggestion~)
    }
    StringLiteralMultiplyNumber(loc) => {
      let antipattern =
        #|     "<string literal>" * n
      let suggestion =
        #|rewrite to:
        #|
        #|     "<string literal>".repeat(n)
      let replace_condition = "n was an integer expression"
      return report_antipattern(
        loc~,
        antipattern~,
        suggestion~,
        replace_condition~,
      )
    }
    CStyleForLoop(loc) => {
      let antipattern =
        #|     for i = 0; i < items.length(); i = i + 1 {
        #|       ... items[i] ...
        #|     }
      let suggestion =
        #|rewrite to:
        #|
        #|     for item in items {
        #|       ... item ...
        #|     }
      return report_antipattern(loc~, antipattern~, suggestion~)
    }
    ConsecutivePrintln(loc) => {
      let antipattern =
        #|     println("line 1")
        #|     println("line 2")
        #|     println("line 3")
      let suggestion =
        #|rewrite to:
        #|
        #|     let msg =
        #|       #|line 1
        #|       #|line 2
        #|       #|line 3
        #|     println(msg)
      return report_antipattern(loc~, antipattern~, suggestion~)
    }
  }
}

///|
fn main {
  let argv = @sys.get_cli_args()[1:].to_array()
  let spec : Array[(String, String, @ArgParser.Spec, String)] = []
  let filenames = []
  let usage =
    #| usage: 
    #|   moonlint.exe <file1> <file2> ...
  @ArgParser.parse(spec, filename => filenames.push(filename), usage, argv) catch {
    err => {
      println(err)
      panic()
    }
  }
  if filenames.length() == 0 {
    let base = get_src_location(load_module_info()) catch {
      err => {
        println("failed to load module info: \{err}")
        panic()
      }
    }
    let mbt_set = get_mbt_path_set_from_base(base) catch {
      err => {
        println("failed when finding source files: \{err}")
        panic()
      }
    }
    for filename in mbt_set {
      filenames.push(filename)
    }
  }
  // make output more human-friendly
  println(" ")
  for filename in filenames {
    let warnings = lint_file(filename) catch {
      err => {
        println(err)
        panic()
      }
    }
    for warning in warnings {
      let msg = message_for_warning(warning)
      println(msg)
    }
  }
}

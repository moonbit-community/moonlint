///|
fn read_mbt_file_to_impls(filename : String) -> @syntax.Impls raise {
  let source = @fs.read_file_to_string(filename)
  let (impls, reports) = @parser.parse_string(source, name=filename)
  if reports.length() > 0 {
    for report in reports {
      fail(report.to_string())
    }
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
fn message_for_warning(warning : @moonlint.Warning) -> String {
  match warning {
    MatchTryQuestion(loc) => {
      let msg =
        $| found anti-pattern at \{loc}:
        #|     match try? expr {
        #|       Ok(...) => branch_ok
        #|       Err(err) => branch_err
        #|     }
        #| rewrite it to:
        #|     branch_ok catch {
        #|       err => branch_err
        #|     }
      return msg
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
  @ArgParser.parse(spec, filename => filenames.push(filename), usage, argv)
  for filename in filenames {
    let warnings = match (try? lint_file(filename)) {
      Err(err) => {
        println(err)
        panic()
      }
      Ok(warning) => warning
    }
    for warning in warnings {
      let msg = message_for_warning(warning)
      println(msg)
    }
  }
}

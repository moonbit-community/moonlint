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
        #|     match (try? expr) {
        #|       Ok(value) => <branch_ok>
        #|       Err(err) => <branch_err>
        #|     }
        #| rewrite it to:
        #|     let value = expr catch {
        #|       err => <branch_err>
        #|     }
        #|     <branch_ok>
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

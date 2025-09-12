///|
#callsite(autofill(loc))
fn is_directory(path : String, loc~ : SourceLoc) -> Bool raise Error {
  @fs.is_dir(path) catch {
    err => fail("failed to check if \{path} is a directory: \{err}", loc~)
  }
}

///|
fn need_ignore(path : String) -> Bool {
  let ignore_list = ["target", ".git", ".mooncakes", ".github", ".moonagent"]
  ignore_list.contains(path)
}

///|
fn get_mbt_path_set_from_base(base : String) -> Array[String] raise Error {
  let mbt_set = Array::new(capacity=20)
  let path_set = @fs.read_dir(base) catch {
    err => fail("failed to read directory \{base}: \{err}")
  }
  let path_set = {
    let q = @queue.new()
    for path in path_set {
      // ignore target directory
      if !(base == "." && need_ignore(path)) {
        q.push(base + "/" + path)
      }
    } else {
      q
    }
  }
  while not(path_set.is_empty()) {
    let path = path_set.unsafe_pop()
    if not(@fs.path_exists(path)) {
      println("invalid path construct by moonlint internal: \{path}")
    }
    if is_directory(path) {
      let new_path_set = @fs.read_dir(path) catch {
        err => fail("failed to read directory \{base}: \{err}")
      }
      for new_path in new_path_set {
        path_set.push(path + "/" + new_path)
      }
    } else if path.has_suffix(".mbt") {
      mbt_set.push(path)
    }
  } else {
    return mbt_set
  }
}

///|
fn load_module_info() -> Json raise Error {
  let text = @fs.read_file_to_string("moon.mod.json")
  @json.parse(text)
}

///|
fn get_src_location(module_info : Json) -> String {
  if module_info.value("source") is Some(src) {
    return src.as_string().unwrap()
  } else {
    return "."
  }
}

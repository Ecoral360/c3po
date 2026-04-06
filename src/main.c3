module c3po;
import std::io;
import std::collections::maybe;
import std::collections::object;
import std::os::process;

import seali;


struct Cli @Command("c3po") {
  Maybe{CmdAdd} add @Seali(@arg(subcommand));
}

struct CmdAdd @Command("add") @About("Install a lib") {
  String repo @Seali(@arg(required));
}

fn void? handle_add_submodules(String path, Object* deps) {
  File project_file_r = io::file::open(string::tformat("%s/manifest.json", path), "r")!;
  defer (void)project_file_r.close();

  Object* obj = json::tparse(&project_file_r)!;

  String lib_name = obj.get_string("provides")!;

  bool found = false;
  for (int i = 0; i < deps.get_len(); i++) {
    if (deps.get_string_at(i)! == lib_name) {
      found = true;
      break;
    }
  }
  if (!found) {
    deps.push(lib_name);
  }

  Object*? subdeps = obj.get("vendor").get("c3po");

  if (catch subdeps) {
    return;
  }
  for (int i = 0; i < subdeps.get_len(); i++) {
    Object* dep = subdeps.get_at(i);
    handle_add({ .repo = dep.get_string("source")! }, deps)!;
  }
}

fn void? handle_add(CmdAdd add, Object* deps = null) {
  String lib_name = add.repo.tsplit("/")[^1].strip_end(".c3l");

  io::printn(@textify("  %{GREEN}%{BOLD}Updating%{RESET} project.json"));

  io::printn(@textify("    %{GREEN}%{BOLD}Adding%{RESET} %s", lib_name));

  File project_file_r = io::file::open("project.json", "r")!;
  defer (void)project_file_r.close();

  Object* obj = json::tparse(&project_file_r)!;

  Object* old_deps = obj.get("dependencies")!;
  if (deps == null) {
    deps = old_deps;
  }

  bool found = false;
  for (int i = 0; i < deps.get_len(); i++) {
    if (deps.get_string_at(i)! == lib_name) {
      found = true;
      break;
    }
  }

  if (found) {
    io::printn(@textify("      %{DIM}%{BOLD}Skipping%{RESET}%{DIM} '%s' (already in lib)", add.repo));
    return;
  }

  Process? p = process::spawn({
    "git", 
    "clone", 
    string::format(mem, "https://github.com/%s", add.repo),
    string::format(mem, "lib/%s.c3l", lib_name),
  });

  if (catch p) {
    io::eprintn("Error executing the command. Make sure git is installed and the lib dir exists.");
    return;
  }

  int code = p.join()!;

  if (code != 0) {
    io::eprintfn("Error cloning the lib '%s'", add.repo);
    return;
  }

  handle_add_submodules(string::tformat("lib/%s.c3l", lib_name), deps)!;

  File project_file_w = io::file::open("project.json", "w")!;
  defer (void)project_file_w.close();

  io::fprintfn(&project_file_w, "%s", obj);
}

fn int main(String[] args) {
  Cli cli = seali::parse(Cli, args)!!;

  if (try cli.add.get()) {
    handle_add(cli.add.value)!!;
  }

	return 0;
}

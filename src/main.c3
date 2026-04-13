module c3po;
import std::io;
import std::collections::maybe;
import std::collections::object;
import std::os::process;
import std::io::path;

import seali;

faultdef INVALID_LIB_DIR;

struct Cli @Command("c3po") {
  Maybe{CmdAdd} add @Seali(@arg(subcommand));

  // Maybe{CmdRemove} remove @Seali(@arg(subcommand));

  Maybe{CmdUpdate} update @Seali(@arg(subcommand));
}

struct CmdAdd @Command("add") @About("Install a lib") {
  String repo;
}

struct CmdRemove @Command("remove") @About("Remove a lib") {
  String name;
}

struct CmdUpdate @Command("update") @About("Update libs") {
  Maybe{String} name @Seali(@arg(short, long));
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

  process::SubProcess? p = process::create({
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


fn void? handle_remove(CmdRemove remove) {
}

fn void? handle_update_of(Path lib_path) {
  process::SubProcess? p = process::create({
    "git",
    "-C",
    lib_path.str_view(),
    "pull",
  });

  if (catch p) {
    io::eprintn("Error executing the command.");
    return;
  }

  int code = p.join()!;

  if (code != 0) {
    io::eprintfn(@textify("  %{RED}%{BOLD}Error%{RESET} updating the lib '%s'", lib_path));
    return;
  }

  Path? lib_dir = lib_path.append(mem, "lib");
  if (catch lib_dir) return;

  return handle_update({}, lib_dir);
}

fn void? handle_update(CmdUpdate update, Path lib_dir) {
  if (try update.name.get()) {
    String lib_name = update.name.value.tsplit("/")[^1].strip_end(".c3l");
    io::printn(@textify("  %{GREEN}%{BOLD}Updating%{RESET} %s", lib_name));
    handle_update_of(path::new(mem, update.name.value.concat(mem, ".c3l")))!;
    return;
  }

  if (!path::is_dir(lib_dir)) {
    return INVALID_LIB_DIR~;
  }

  PathList libs = path::ls(mem, lib_dir)!;

  foreach (lib : libs) {
    Path lib_path = lib_dir.append(mem, lib.str_view())!;
    if (path::is_dir(lib_path)) {
      String lib_name = lib.basename().tsplit("/")[^1].strip_end(".c3l");
      io::printn(@textify("  %{GREEN}%{BOLD}Updating%{RESET} %s", lib_name));
      handle_update_of(lib_path)!;
    }
  }

}

fn int main(String[] args) {
  Cli cli = seali::parse(Cli, args)!!;

  if (try cli.add.get()) {
    (void)path::mkdir("./lib", true)!!;
    handle_add(cli.add.value)!!;
  }

  // if (try cli.remove.get()) {
  //   handle_remove(cli.remove.value)!!;
  // }

  if (try cli.update.get()) {
    Path? lib_dir = path::new(mem, "./lib");
    if (catch lib_dir) {
      io::printn(@textify("%{DIM}%{BOLD}No dependencies to update%{RESET}"));
      return 0;
    }
    handle_update(cli.update.value, lib_dir)!!;
  }

	return 0;
}

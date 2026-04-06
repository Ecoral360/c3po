# c3po 🤖 - C3 Project Orchestrator

A package manager for the [C3 programming language](https://c3-lang.org/) that automates dependency installation and project configuration.

Built with the [`seali`](https://github.com/Ecoral360/seali.c3l) CLI framework.

## Features

- Install C3 libraries directly from GitHub repositories
- Automatic `project.json` dependency management
- Transitive dependency resolution via `manifest.json`
- Duplicate dependency detection

## Requirements

- [C3 compiler](https://c3-lang.org/) (c3c)
- Git

## Build

```bash
c3c build
```

The executable will be at `build/c3po`.

## Usage

```
c3po <COMMANDS>

Commands:
  add  Install a lib
```

### `c3po add`

Install a library from a GitHub repository:

```bash
c3po add <owner/repo>
```

**Example:**

```bash
c3po add Ecoral360/seali
```

This will:

1. Clone `https://github.com/Ecoral360/seali` into `lib/seali.c3l/`
2. Read the library's `manifest.json` to resolve its name and sub-dependencies
3. Update your `project.json` dependencies list
4. Recursively install any transitive dependencies declared in `vendor.c3po`

### Library manifest format

Libraries installed by c3po should include a `manifest.json`:

```json
{
  "provides": "library_name",
  "vendor": {
    "c3po": [
      { "source": "owner/repo" }
    ]
  }
}
```

- `provides` — the library name to register in `project.json` dependencies
- `vendor.c3po` — optional list of transitive dependencies to install

## Project Structure

```
c3po/
├── src/
│   ├── main.c3    # CLI commands and dependency management
│   ├── json.c3    # JSON parser
│   └── text.c3    # ANSI color formatting utilities
├── lib/           # Installed dependencies
├── project.json   # C3 project configuration
└── build/         # Compiled output
```

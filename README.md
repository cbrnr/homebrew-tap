# Homebrew tap for Quarto

An unofficial [Homebrew](https://brew.sh) tap with a `quarto` **formula** that builds [Quarto](https://quarto.org) from source against Homebrew's own `deno`, `pandoc`, `dart-sass`, `esbuild` and `typst`. Unlike the cask, it also works on Linux.

## Install

You need Homebrew 7 or later (`brew update`). If you have the `quarto` cask installed, remove it first, because both install a `quarto` command:

```sh
brew uninstall --cask quarto
brew install cbrnr/tap/quarto
```

Upgrade and uninstall work as usual (`brew upgrade quarto`, `brew uninstall quarto`).

## Platforms

| Platform | Install |
|---|---|
| macOS 26 (Tahoe), Apple Silicon | prebuilt bottle |
| Linux x86_64 | prebuilt bottle |
| Other macOS versions, Linux on ARM | builds from source |
| Intel macOS | not supported |

## Differences from the official Quarto installer

- **Dependency versions.** Quarto pins specific versions of Pandoc, Deno, Dart Sass and esbuild. This formula uses whatever versions Homebrew currently ships, which are often newer.
- **Typst.** Quarto finds Typst only through the `QUARTO_TYPST` variable, which the formula sets. `typst-gather` is built from source.
- **deno_dom.** The native plugin is not included, so Quarto falls back to its slower WASM version.

## Reporting problems

Open an issue in this repository: <https://github.com/cbrnr/homebrew-tap/issues>. Include the output of `brew config` and `quarto check`. For problems that also occur with the official Quarto installer, report them to [quarto-dev/quarto-cli](https://github.com/quarto-dev/quarto-cli/issues) instead.

## Maintenance

New Quarto releases are picked up daily by an autobump workflow, which opens a pull request. CI builds and tests each pull request on macOS and Linux, and a maintainer publishes the bottles. See [Homebrew's tap documentation](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap) for how this works.

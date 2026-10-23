class Quarto < Formula
  desc "Scientific and technical publishing system built on Pandoc"
  homepage "https://quarto.org/"
  url "https://github.com/quarto-dev/quarto-cli/archive/refs/tags/v1.10.19.tar.gz"
  sha256 "99bd1aaaf1fc81dfe40185918994eaa35e30643d0059bec91b9fd47b2c3d5d6e"
  license "MIT"

  # Upstream tags prereleases (e.g. v1.11.x) without a suffix, so only
  # consider the release marked as latest on GitHub.
  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "node" => :build
  depends_on "rust" => :build

  depends_on "dart-sass"
  depends_on "deno"
  depends_on "esbuild"
  depends_on "pandoc"
  depends_on "typst"

  # Keep in sync with `TYPST_GATHER` in the `configuration` file.
  resource "typst-gather" do
    url "https://github.com/quarto-dev/typst-gather/archive/refs/tags/v0.2.3.tar.gz"
    sha256 "dc04f2285b0b0d4b981f14f6a3ed02a09ca9b91aa7e56509ecd25c7ab5a25ee3"
  end

  def fetch
    setup_build_environment

    resource("typst-gather").stage do
      system "cargo", "fetch", *std_cargo_fetch_args
    end

    # With QUARTO_VENDOR_BINARIES=false, `quarto-bld configure` fails unless
    # typst-gather is on PATH, although it is not needed until `prepare-dist`.
    # Satisfy the check with a stub until it is built in `install`.
    # https://github.com/orgs/quarto-dev/discussions/14888
    typst_gather_stub = buildpath/"homebrew-fetch-bin/typst-gather"
    typst_gather_stub.dirname.mkpath
    typst_gather_stub.write "#!/bin/sh\nexit 0\n"
    chmod 0755, typst_gather_stub
    ENV.prepend_path "PATH", typst_gather_stub.dirname

    # `configure.sh` vendors Deno dependencies with `deno install`, which no
    # longer works with current Deno and fails silently, so cache all build and
    # runtime entry points explicitly.
    system "bash", "configure.sh"
    system formula_opt_bin("deno")/"deno", "cache",
           "--allow-import",
           "--no-config",
           "--import-map=#{buildpath}/src/import_map.json",
           "package/src/bld.ts",
           "package/scripts/deno_std/deno_std.ts",
           "src/quarto.ts",
           "src/vendor_deps.ts",
           "tools/deno-esbuild-bundle.ts"
  end

  def install
    setup_build_environment

    typst_gather_prefix = buildpath/"typst-gather-prefix"
    resource("typst-gather").stage do
      system "cargo", "install", *std_cargo_args(root: typst_gather_prefix)
    end
    ENV["QUARTO_TYPST_GATHER"] = typst_gather_prefix/"bin/typst-gather"
    ENV.prepend_path "PATH", typst_gather_prefix/"bin"
    ENV["NPM_CONFIG_OFFLINE"] = "true"

    system "bash", "package/src/quarto-bld", "prepare-dist", "--set-version", version.to_s
    system "bash", "package/src/quarto-bld", "make-installer-dir", "--set-version", version.to_s

    libexec.install (buildpath/"homebrew-dist").children
    (libexec/"bin").install typst_gather_prefix/"bin/typst-gather"

    # The VS Code extension adds the first path reported by `quarto --paths`
    # to integrated terminals. Make that internal entry point safe to invoke
    # directly as well as through Homebrew's public symlink.
    quarto_launcher = libexec/"bin/quarto"
    quarto_real = libexec/"bin/quarto-real"
    quarto_launcher.rename quarto_real
    quarto_launcher.write_env_script quarto_real, tool_env.merge(
      "QUARTO_SHARE_PATH"   => opt_libexec/"share/quarto",
      "QUARTO_TYPST_GATHER" => opt_libexec/"bin/typst-gather",
    )
    bin.install_symlink quarto_launcher
  end

  private

  def tool_env
    {
      "QUARTO_DART_SASS" => formula_opt_bin("dart-sass")/"sass",
      "QUARTO_DENO"      => formula_opt_bin("deno")/"deno",
      "QUARTO_ESBUILD"   => formula_opt_bin("esbuild")/"esbuild",
      "QUARTO_PANDOC"    => formula_opt_bin("pandoc")/"pandoc",
      "QUARTO_TYPST"     => formula_opt_bin("typst")/"typst",
    }
  end

  def setup_build_environment
    dist = buildpath/"homebrew-dist"
    # Keep the cache outside of `dist`, which is installed into `libexec`.
    deno_dir = buildpath/".deno_cache"
    # `quarto-bld configure` copies its launcher here without creating it.
    (dist/"bin").mkpath

    ENV["DENO_DIR"] = deno_dir
    ENV["QUARTO_VENDOR_BINARIES"] = "false"
    ENV["QUARTO_NO_SYMLINK"] = "1"
    ENV["QUARTO_DIST_PATH"] = dist
    ENV["QUARTO_SHARE_PATH"] = dist/"share/quarto"
    ENV["QUARTO_DENO_DIR"] = deno_dir
    ENV["DENO_BIN_PATH"] = formula_opt_bin("deno")/"deno"
    ENV["DENO_DOM_PLUGIN"] = ""
    ENV["NPM_CONFIG_IGNORE_SCRIPTS"] = "true"
    tool_env.each { |key, value| ENV[key] = value }
  end

  test do
    assert_equal version.to_s, shell_output("#{bin}/quarto --version").strip

    (testpath/"test.qmd").write <<~MARKDOWN
      ---
      title: Homebrew test
      ---

      Quarto rendered this document.
    MARKDOWN

    system bin/"quarto", "render", "test.qmd", "--to", "html"
    assert_path_exists testpath/"test.html"
  end
end

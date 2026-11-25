{ stdenvNoCC, fetchurl, makeWrapper, runCommandLocal }:
{
  # bin/hcx and scripts/hcx-migrate-herdr, unchanged: they're plain bash, run against the
  # system's jq, lsof and sysctl, and the user's ~/.local/bin/{hc,rex,omp}.
  hcx = runCommandLocal "hcx" { } ''
    install -Dm755 ${../bin/hcx} $out/bin/hcx
    install -Dm755 ${../scripts/hcx-migrate-herdr} $out/bin/hcx-migrate-herdr
  '';

  # hc-tui, the terminal UI for herdr-core, from the ionnich/hc-tui fork (Apache-2.0) of
  # followcat/hc-tui, prebuilt by the fork's own release workflow.
  # Bump: tag the fork (vX.Y.Z-ionnich.N) so its workflow builds it, change `version`, then copy
  # the aarch64-apple-darwin line of the release's sha256sums.txt into `sha256`.
  hc-tui = stdenvNoCC.mkDerivation rec {
    pname = "hc-tui";
    version = "0.1.20-ionnich.1";
    src = fetchurl {
      url = "https://github.com/ionnich/hc-tui/releases/download/v${version}/hc-tui-${version}-aarch64-apple-darwin.tar.gz";
      sha256 = "aa26ef73b0b730cd9c6339b63452a4fa94569438cb47c078e08f61dfbc4a02fd";
    };
    nativeBuildInputs = [ makeWrapper ];
    sourceRoot = ".";
    dontFixup = true; # the release binary is signed; stripping or patching would break that
    installPhase = ''
      runHook preInstall
      install -Dm755 hc-tui $out/libexec/hc-tui
      # Its update check and --upgrade point at followcat's releases; this build is the fork,
      # updated by bumping this file.
      makeWrapper $out/libexec/hc-tui $out/bin/hc-tui --set HC_TUI_NO_UPDATE_CHECK 1
      runHook postInstall
    '';
  };
}

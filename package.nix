{
  lib,
  stdenv,
  fetchFromGitHub,
  nodejs,
  pnpm,
  fetchPnpmDeps,
  pnpmConfigHook,
  makeWrapper,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "openclaw";
  version = "2026.1.29";

  src = fetchFromGitHub {
    owner = "openclaw";
    repo = "openclaw";
    rev = "v${finalAttrs.version}";
    hash = "sha256-ZH3j3Sz0uZ8ofbGOj7ANgIW9j+lhknnAsa7ZI0wWo1o=";
  };

  nativeBuildInputs = [
    nodejs
    pnpm
    pnpmConfigHook
    makeWrapper
  ];

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    hash = "sha256-P7iHHbnuOMS8dV72FdrZVI7X9yCAYjvuRaCWPqu/Qvs=";
    fetcherVersion = 1;
  };

  buildPhase = ''
    runHook preBuild
    pnpm build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/openclaw $out/bin
    cp -r dist node_modules package.json $out/lib/openclaw/
    cp -r extensions $out/lib/openclaw/ 2>/dev/null || true
    cp -r apps $out/lib/openclaw/ 2>/dev/null || true
    cp -r skills $out/lib/openclaw/ 2>/dev/null || true
    cp -r docs $out/lib/openclaw/ 2>/dev/null || true
    makeWrapper ${nodejs}/bin/node $out/bin/openclaw \
      --add-flags "$out/lib/openclaw/dist/entry.js"
    runHook postInstall
  '';

  preFixup = ''
    find $out -xtype l -delete 2>/dev/null || true
  '';

  meta = {
    homepage = "https://openclaw.ai";
    description = "AI assistant gateway for messaging platforms";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    mainProgram = "openclaw";
  };
})

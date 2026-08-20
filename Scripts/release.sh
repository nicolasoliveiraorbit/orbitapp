#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="Orbit.xcodeproj"
SCHEME_NAME="Orbit"
CONFIGURATION="Release"
GH_REPO="nicolasoliveiraorbit/orbitapp"

log() {
    printf '%s\n' "==> $*"
}

fail() {
    printf '%s\n' "error: $*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || fail "Comando obrigatório não encontrado: $1"
}

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || fail "Execute este script dentro do repositório Git."
cd "$repo_root"

require_command git
require_command xcodebuild
require_command gh
require_command ditto
require_command awk

[[ -d "$PROJECT_NAME" ]] || fail "Projeto Xcode não encontrado: $PROJECT_NAME"

if ! git diff --quiet || ! git diff --cached --quiet; then
    fail "A árvore Git tem alterações não commitadas. Faça commit/stash antes de publicar uma release reproduzível."
fi

if ! git remote get-url origin >/dev/null 2>&1; then
    fail "Remote Git 'origin' não configurado."
fi

origin_url="$(git remote get-url origin)"
case "$origin_url" in
    *github.com:nicolasoliveiraorbit/orbitapp.git|*github.com/nicolasoliveiraorbit/orbitapp.git)
        ;;
    *)
        fail "Remote 'origin' aponta para '$origin_url', não para github.com/nicolasoliveiraorbit/orbitapp."
        ;;
esac

gh auth status --hostname github.com >/dev/null 2>&1 || fail "GitHub CLI não autenticado. Rode: gh auth login"

build_root="$repo_root/.build/release"
work_root="$(mktemp -d "${TMPDIR:-/tmp}/orbit-release.XXXXXX")"
derived_data_path="$work_root/DerivedData"
archive_path="$work_root/Orbit.xcarchive"

rm -rf "$build_root"
mkdir -p "$build_root"
trap 'rm -rf "$work_root"' EXIT

log "Lendo configurações Release do Xcode"
build_settings="$(
    xcodebuild \
        -project "$PROJECT_NAME" \
        -scheme "$SCHEME_NAME" \
        -configuration "$CONFIGURATION" \
        -destination 'generic/platform=macOS' \
        -derivedDataPath "$derived_data_path" \
        -showBuildSettings \
        ARCHS=arm64
)"

marketing_version="$(printf '%s\n' "$build_settings" | awk -F '= ' '/^[[:space:]]*MARKETING_VERSION = / { print $2; exit }')"
product_name="$(printf '%s\n' "$build_settings" | awk -F '= ' '/^[[:space:]]*PRODUCT_NAME = / { print $2; exit }')"
bundle_identifier="$(printf '%s\n' "$build_settings" | awk -F '= ' '/^[[:space:]]*PRODUCT_BUNDLE_IDENTIFIER = / { print $2; exit }')"
code_sign_style="$(printf '%s\n' "$build_settings" | awk -F '= ' '/^[[:space:]]*CODE_SIGN_STYLE = / { print $2; exit }')"
development_team="$(printf '%s\n' "$build_settings" | awk -F '= ' '/^[[:space:]]*DEVELOPMENT_TEAM = / { print $2; exit }')"
entitlements_file="$(printf '%s\n' "$build_settings" | awk -F '= ' '/^[[:space:]]*CODE_SIGN_ENTITLEMENTS = / { print $2; exit }')"

[[ -n "$marketing_version" ]] || fail "MARKETING_VERSION não encontrado nas configurações do Xcode."
[[ -n "$product_name" ]] || fail "PRODUCT_NAME não encontrado nas configurações do Xcode."
[[ "$marketing_version" =~ ^[0-9]+(\.[0-9]+){1,2}([.-][A-Za-z0-9]+)?$ ]] || fail "MARKETING_VERSION '$marketing_version' não parece uma versão publicável."
[[ -n "$code_sign_style" ]] || fail "CODE_SIGN_STYLE não encontrado nas configurações do Xcode."
[[ -n "$development_team" ]] || fail "DEVELOPMENT_TEAM não encontrado. Configure Signing & Capabilities no Xcode antes de publicar."

tag="v$marketing_version"
zip_name="Orbit-$tag.zip"
zip_path="$build_root/$zip_name"

log "Release alvo: $tag"
log "Produto: $product_name.app"
log "Bundle identifier: $bundle_identifier"
log "Signing: $code_sign_style / Team $development_team"
[[ -n "$entitlements_file" ]] && log "Entitlements: $entitlements_file"

if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
    fail "Tag local já existe: $tag"
fi

if git ls-remote --exit-code --tags origin "refs/tags/$tag" >/dev/null 2>&1; then
    fail "Tag remota já existe: $tag"
fi

if gh release view "$tag" --repo "$GH_REPO" >/dev/null 2>&1; then
    fail "GitHub Release já existe: $tag"
fi

log "Compilando archive Release"
xcodebuild \
    -project "$PROJECT_NAME" \
    -scheme "$SCHEME_NAME" \
    -configuration "$CONFIGURATION" \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$derived_data_path" \
    -archivePath "$archive_path" \
    archive \
    ARCHS=arm64

app_path="$archive_path/Products/Applications/$product_name.app"
[[ -d "$app_path" ]] || fail "App gerado não encontrado em: $app_path"

log "Validando assinatura"
codesign --verify --deep --strict --verbose=2 "$app_path"

log "Gerando ZIP: $zip_name"
ditto -c -k --keepParent "$app_path" "$zip_path"
[[ -f "$zip_path" ]] || fail "ZIP não foi criado: $zip_path"

log "Criando GitHub Release e tag $tag"
commit_sha="$(git rev-parse HEAD)"
gh release create "$tag" "$zip_path" \
    --repo "$GH_REPO" \
    --target "$commit_sha" \
    --title "Orbit $tag" \
    --notes "Release $tag"

log "Release publicada com sucesso"
log "Arquivo: $zip_path"
log "URL: https://github.com/$GH_REPO/releases/tag/$tag"

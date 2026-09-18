#!/usr/bin/env bash

# Salir inmediatamente si algún comando falla y mostrar el número de línea del error
set -e
trap 'echo "❌ Error en libwallet-android.sh en la línea $LINENO"' ERR

repo_root=$(git rev-parse --show-toplevel)
build_dir="$repo_root/libwallet/.build"

# OSS project has a different folder libwallet aar, so we receive it as param
libwallet="$1"
if [[ ! -s "$1" ]]; then
    libwallet="$repo_root/android/libwallet/libs/libwallet.aar"
fi

cd "$repo_root/libwallet"

mkdir -p "$(dirname "$libwallet")"

# Create the cache folders
mkdir -p "$build_dir/android"
mkdir -p "$build_dir/pkg"

export GOCACHE="$build_dir/android"
export GOPATH="$build_dir/pkg"

# Verificar que Go esté disponible
if ! command -v go &> /dev/null; then
    echo "❌ Error: Go no está instalado o no se encuentra en el PATH."
    exit 1
fi

# Install and setup gomobile on demand (no-op if already installed and up-to-date)
if [[ -f "$repo_root/tools/bootstrap-gomobile.sh" ]]; then
    . "$repo_root/tools/bootstrap-gomobile.sh"
else
    echo "❌ Error: No se encontró el script bootstrap-gomobile.sh en tools/"
    exit 1
fi

# gomobile bind generates the src-android-* directories several times, leading to fail with:
# /tmp/go-build.../b001/exe/gomobile: mkdir $GOCACHE/src-android-arm64: file exists
rm -rf "$GOCACHE"/src-android-* 2>/dev/null \
  || echo "No src-android-* directories found in GOCACHE."

# Set linker flags for 16KB page alignment required by Android targetSdk 35+
export CGO_LDFLAGS="-Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384"

echo "🚀 Iniciando gomobile bind..."

# Finalmente ejecutar gomobile bind apuntando únicamente al paquete principal (.)
# Se desactiva temporalmente set -e para capturar correctamente el código de salida
set +e
go run golang.org/x/mobile/cmd/gomobile bind \
    -target="android" -o "$libwallet" \
    -androidapi 21 \
    -trimpath -ldflags="-buildid=. -v" \
    .

st=$?
set -e

if [ $st -eq 0 ]; then
    echo "✅ gomobile compilado exitosamente en $libwallet"
else
    echo "❌ Error: gomobile bind falló con el código de salida $st"
fi

exit $st

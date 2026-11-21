#!/bin/bash
# ==============================================================================
# Esteira de Versionamento e Build Automatizado • b-cam
# Executa bump de versão, compilação de binários, geração de manifesto e deploy OTA
# ==============================================================================

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "========================================================="
echo "🚀 b-cam • Pipeline Automatizado de Build & Versionamento"
echo "========================================================="

# 1. Leitura e Incremento de Versão no pubspec.yaml
CURRENT_VERSION_LINE=$(grep '^version:' pubspec.yaml)
CURRENT_VERSION_RAW=$(echo "$CURRENT_VERSION_LINE" | awk '{print $2}')
CURRENT_VERSION_NAME=$(echo "$CURRENT_VERSION_RAW" | cut -d'+' -f1)
CURRENT_BUILD_NUMBER=$(echo "$CURRENT_VERSION_RAW" | cut -d'+' -f2)

MAJOR=$(echo "$CURRENT_VERSION_NAME" | cut -d'.' -f1)
MINOR=$(echo "$CURRENT_VERSION_NAME" | cut -d'.' -f2)
PATCH=$(echo "$CURRENT_VERSION_NAME" | cut -d'.' -f3)

# Incremento padrão de Minor/Patch para o novo ciclo (1.2.0 + Build 3)
NEW_MAJOR=$MAJOR
NEW_MINOR=$((MINOR + 1))
NEW_PATCH=0
NEW_BUILD=$((CURRENT_BUILD_NUMBER + 1))
NEW_VERSION_RAW="${NEW_MAJOR}.${NEW_MINOR}.${NEW_PATCH}+${NEW_BUILD}"
NEW_VERSION_NAME="${NEW_MAJOR}.${NEW_MINOR}.${NEW_PATCH}"

echo "Versão Atual: $CURRENT_VERSION_RAW"
echo "Nova Versão Calculada: $NEW_VERSION_RAW (Build $NEW_BUILD)"

# Atualiza pubspec.yaml
sed -i '' "s/^version: .*/version: $NEW_VERSION_RAW/" pubspec.yaml

# 2. Execução da Suíte de Testes
echo "Executando testes automatizados..."
flutter test

# 3. Compilação dos Binários Otimizados (Split per ABI)
echo "Compilando APKs de produção/depuração otimizados..."
flutter build apk --debug --split-per-abi

# 4. Publicação em dist/ e Geração de Checksum
mkdir -p dist
cp build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk dist/b-cam-arm64.apk
cp build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk dist/b-cam-latest.apk

APK_SIZE=$(stat -f%z dist/b-cam-arm64.apk 2>/dev/null || stat -c%s dist/b-cam-arm64.apk)
APK_SHA256=$(shasum -a 256 dist/b-cam-arm64.apk | awk '{print $1}')
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

cat <<EOF > dist/version.json
{
  "versionCode": $NEW_BUILD,
  "versionName": "$NEW_VERSION_NAME",
  "apkUrl": "http://192.168.3.62:8088/b-cam-arm64.apk",
  "sha256": "$APK_SHA256",
  "fileSizeBytes": $APK_SIZE,
  "releaseNotes": "Versão 1.29.0: Auto-fallback de codec HD para Sub Stream (SD/H.264), correção de roteamento Cloud Relay na LAN e reconciliação automática de IP via DHCP no radar.",
  "releaseDate": "$TIMESTAMP"
}
EOF
cp dist/version.json public/version.json

echo "✔ Manifesto gerado com sucesso em dist/version.json"
echo "  Tamanho: $(($APK_SIZE / 1024 / 1024)) MB | SHA256: ${APK_SHA256:0:16}..."

# 5. Reinicializa Servidor de Distribuição se não estiver ativo
if ! pgrep -f "distribution_server.py" > /dev/null; then
  echo "Iniciando servidor de distribuição HTTP em segundo plano..."
  python3 scripts/distribution_server.py > /dev/null 2>&1 &
fi

# 6. Deploy Autônomo se Dispositivo Conectado
if [ -f "scripts/deploy_to_phone.sh" ]; then
  echo "Disparando deploy autônomo OTA para o dispositivo via Wi-Fi..."
  ./scripts/deploy_to_phone.sh
fi

echo "========================================================="
echo "🎉 Build e Release v$NEW_VERSION_RAW concluído com sucesso!"
echo "========================================================="

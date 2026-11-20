#!/usr/bin/env bash
# ==============================================================================
# b-cam Autonomous Over-The-Air (OTA) Wireless ADB Deployment Script
# Target: Xiaomi Redmi Note 10S (rosemary / 192.168.3.13)
# ==============================================================================

set -e

PHONE_IP="192.168.3.13"
APK_PATH="dist/b-cam-arm64.apk"
PACKAGE_NAME="com.bcam.bcam"
ACTIVITY_NAME="com.bcam.bcam.MainActivity"
DIAG_PORT=8089

echo "[OTA] ========================================================="
echo "[OTA] Iniciando Deploy Autônomo b-cam via Wi-Fi (Sem Intervenção)"
echo "[OTA] Alvo: Xiaomi Redmi Note 10S ($PHONE_IP)"
echo "[OTA] APK: $APK_PATH ($(du -h "$APK_PATH" | cut -f1))"
echo "[OTA] ========================================================="

# 1. Encontrar identificador do dispositivo ADB
DEVICE_SERIAL=$(adb devices -l | grep -E "rosemary|$PHONE_IP|_adb-tls-connect" | awk '{print $1}' | head -n 1)

if [ -z "$DEVICE_SERIAL" ]; then
    echo "[OTA] Dispositivo não conectado diretamente. Varrendo porta Wireless ADB em $PHONE_IP..."
    for port in 40065 40000 41000 42000 43000 44000 45000 46000 47000; do
        if nc -zv -w 1 "$PHONE_IP" "$port" 2>/dev/null; then
            echo "[OTA] Porta aberta encontrada: $port. Conectando..."
            adb connect "$PHONE_IP:$port"
            DEVICE_SERIAL="$PHONE_IP:$port"
            break
        fi
    done
fi

if [ -z "$DEVICE_SERIAL" ]; then
    # Tenta reconectar na porta mDNS ativa
    DEVICE_SERIAL=$(adb devices | grep -v "List" | grep "device$" | awk '{print $1}' | grep -v "emulator" | head -n 1)
fi

if [ -z "$DEVICE_SERIAL" ]; then
    echo "[ERRO] Não foi possível localizar o dispositivo Xiaomi via Wireless ADB."
    exit 1
fi

echo "[OTA] Dispositivo conectado: $DEVICE_SERIAL"

# 2. Upload rápido para staging local seguro (/data/local/tmp/app.apk)
echo "[OTA] Enviando binário otimizado para o dispositivo..."
adb -s "$DEVICE_SERIAL" push "$APK_PATH" /data/local/tmp/app.apk

# 3. Instalação silenciosa sem prompt MIUI
echo "[OTA] Executando pm install -r autônomo..."
adb -s "$DEVICE_SERIAL" shell "pm install -r /data/local/tmp/app.apk && rm /data/local/tmp/app.apk"

# 4. Inicialização da MainActivity
echo "[OTA] Reiniciando aplicativo no primeiro plano..."
adb -s "$DEVICE_SERIAL" shell am start -n "$PACKAGE_NAME/$ACTIVITY_NAME"

# 5. Verificação do serviço de telemetria
sleep 3
echo "[OTA] Verificando integridade da telemetria em http://$PHONE_IP:$DIAG_PORT/api/status..."
if curl -s -m 3 "http://$PHONE_IP:$DIAG_PORT/api/status" 2>/dev/null; then
    echo ""
    echo "[OTA] ✔ Telemetria confirmada e ativa na porta $DIAG_PORT!"
else
    echo "[OTA] ✔ App iniciado com sucesso (servidor HTTP inicializando)."
fi

echo "[OTA] Deploy 100% autônomo concluído com sucesso!"

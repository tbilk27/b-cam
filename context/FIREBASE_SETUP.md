# 🔥 Parametrização do Firebase & Notificações Push FCM para o b-cam

Este documento descreve como parametrizar o **Firebase** para notificações push com Deeplink no aplicativo **b-cam**, mantendo tudo no plano gratuito permanente (**Spark Plan**).

---

## 1. Passo a Passo no Console do Firebase

### 1. Criar ou Selecionar o Projeto
1. Acesse o [Console do Firebase](https://console.firebase.google.com/).
2. Clique em **Criar projeto** e insira o nome: `b-cam-surveillance`.
3. Desative o Google Analytics (opcional) para agilizar.
4. Confirme que o plano ativo é o **Spark** (Gratuito / $0 por mês).

### 2. Adicionar o App Android
1. No painel do projeto, clique no ícone do **Android**.
2. Preencha o campo **Nome do pacote Android**:
   ```
   com.bcam.bcam
   ```
3. Apelido do app: `b-cam Mobile`.
4. Clique em **Registrar app**.
5. Baixe o arquivo `google-services.json`.
6. Mova o arquivo para a pasta do projeto:
   ```bash
   cp ~/Downloads/google-services.json android/app/google-services.json
   ```

### 3. Configurar Firebase Cloud Messaging (FCM)
1. No menu lateral do Firebase, vá em **Configurações do Projeto** (ícone de engrenagem) > aba **Cloud Messaging**.
2. O canal de notificações no Android é automaticamente configurado pelo app com o identificador:
   - **Channel ID**: `b_cam_surveillance_alerts`
   - **Prioridade**: Alta / Max (Alerta sonoro com vibração e heads-up banner).

---

## 2. Testar Notificação com Deeplink via Terminal (cURL)

Você pode disparar um alerta de teste diretamente para o dispositivo usando a API REST do FCM:

```bash
curl -X POST https://fcm.googleapis.com/fcm/send \
  -H "Content-Type: application/json" \
  -H "Authorization: key=SUA_CHAVE_DE_SERVIDOR_FCM" \
  -d '{
    "to": "/topics/camera_cam-intelbras-frente-74",
    "notification": {
      "title": "🚨 Alerta b-cam: Pessoa Detectada",
      "body": "Intelbras Frente da Casa: Pessoa se aproximando do portão social (Certeza: 96%)"
    },
    "data": {
      "eventId": "evt-74-1",
      "cameraId": "cam-intelbras-frente-74",
      "deepLink": "bcam://event/evt-74-1",
      "click_action": "FLUTTER_NOTIFICATION_CLICK"
    }
  }'
```

---

## 3. Comportamento ao Clicar na Notificação

1. **Deeplink Ativado:** `bcam://event/evt-74-1`.
2. **Abertura Imediata:** O app abre diretamente na tela `EventDetailScreen`.
3. **Visualização:** O usuário visualiza o clipe do evento, a interpretação semântica e as **Bounding Boxes** contornadas sobre a pessoa identificada.

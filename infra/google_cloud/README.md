# ☁️ Infraestrutura Google Cloud & Firebase 100% Gratuita (Custo Zero Perpétuo)

Este documento descreve a arquitetura, configuração e parâmetros para operar o armazenamento, processamento de visão por IA e mensageria de notificações do **b-cam** sem incorrer em custos, utilizando exclusivamente os limites permanentes do **Google Cloud Always Free Tier** e do **Firebase Spark Plan**.

---

## 1. Matriz de Serviços e Limites Gratuitos Perpétuos

| Serviço Google | Plano / Nível | Cota Gratuita Permanente | Custo Estimado | Uso no b-cam |
| :--- | :--- | :--- | :---: | :--- |
| **Google Gemini 1.5 Flash** | Google AI Studio (Free Tier) | **15 requisições/minuto**<br>1.000.000 tokens/minuto<br>1.500 requisições/dia | **R$ 0,00** | Análise multimodal de cenas, detecção de pessoas/veículos, caixas delimitadoras (*bounding boxes*) e interpretação semântica. |
| **Firebase Cloud Messaging (FCM)** | Firebase Spark Plan | **Ilimitado** (sem limite de mensagens push) | **R$ 0,00** | Envio de alertas instantâneos de alta prioridade com payloads de Deeplink (`bcam://event/{id}`). |
| **Google Cloud Functions / Cloud Run** | Always Free Tier | **2.000.000 de invocações/mês**<br>360.000 vCPU-segundos/mês<br>5 GB de tráfego de saída | **R$ 0,00** | Webhook de ingestão de eventos, filtro de limiar de certeza e despacho para FCM. |
| **Cloud Firestore** | Always Free Tier | **1 GB de armazenamento**<br>50.000 leituras/dia<br>20.000 gravações/dia | **R$ 0,00** | Armazenamento de metadados de eventos, histórico da linha do tempo e coordenadas das caixas delimitadoras. |
| **Cloud Storage** | Always Free Tier | **5 GB de armazenamento padrão**<br>5.000 operações Classe A/mês | **R$ 0,00** | Armazenamento de snapshots JPEG otimizados e clipes curtos de evidência. |

---

## 2. Topologia da Arquitetura

```
[ Câmera Local (ex: Intelbras / Yoosee) ]
                  │
                  ▼
         [ b-cam App (Edge) ]
                  │
                  ├────────────────────────┐
                  │ (Se evento gerado)      │ (Chamada Direta ou via Webhook)
                  ▼                         ▼
   [ Firebase Cloud Messaging ]    [ Cloud Functions / Cloud Run ]
   (Disparo Push com Deeplink)             │
                  │                         ▼
                  │           [ Google Gemini 1.5 Flash API ]
                  │           (Detecção de Objetos & Bounding Boxes)
                  │                         │
                  ▼                         ▼
        [ Celular do Usuário ]       [ Cloud Firestore ]
    (Abre vídeo direto no app)    (Gravação se Certeza >= 25%)
```

---

## 3. Guia Rápido de Parametrização do Firebase

### Passo 1: Criar o Projeto Firebase (Sem Cartão de Crédito)
1. Acesse o console [Firebase Console](https://console.firebase.google.com/).
2. Clique em **"Adicionar projeto"** e nomeie como `b-cam-surveillance`.
3. Certifique-se de selecionar o plano **Spark (Gratuito)**.

### Passo 2: Registrar o App Android
1. Adicione um app Android com o pacote: `com.bcam.bcam`.
2. Baixe o arquivo `google-services.json` gerado pelo Firebase.
3. Copie o arquivo para:
   ```bash
   cp ~/Downloads/google-services.json android/app/google-services.json
   ```

### Passo 3: Ativar Cloud Firestore
1. No menu lateral do Firebase, clique em **Firestore Database** > **Criar banco de dados**.
2. Selecione a região mais próxima (ex: `southamerica-east1` em São Paulo).
3. Aplique as regras de segurança fornecidas em `infra/google_cloud/firebase/firestore.rules`.

### Passo 4: Obter a Chave Gratuita do Gemini 1.5 Flash
1. Acesse [Google AI Studio](https://aistudio.google.com/).
2. Clique em **"Get API key"** e gere uma chave gratuita para o projeto.
3. Insira no arquivo de ambiente ou informe no app b-cam em *Configurações > Chave Gemini*.

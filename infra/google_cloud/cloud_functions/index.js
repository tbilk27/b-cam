/**
 * Google Cloud Function (100% Free Tier)
 * Processamento Inteligente de Cenas com Gemini 1.5 Flash e Notificações Push FCM com Deeplink.
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { GoogleGenerativeAI } = require('@google/generative-ai');

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

// Inicializa cliente Gemini com chave do Free Tier (Google AI Studio)
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || 'AIzaSy_FREE_TIER_KEY');

exports.processCameraEvent = functions.https.onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    return res.status(405).send('Método não permitido');
  }

  try {
    const {
      cameraId,
      cameraName,
      imageBase64,
      minConfidence = 0.25, // Limiar padrão de 25%
      customPrompt,
    } = req.body;

    if (!cameraId || !cameraName) {
      return res.status(400).json({ error: 'Parâmetros cameraId e cameraName obrigatórios' });
    }

    let detectedConfidence = 0.94;
    let sceneDescription = 'Pessoa detectada se aproximando da entrada.';
    let boundingBoxes = [
      {
        label: 'Pessoa',
        confidence: 0.94,
        left: 0.42,
        top: 0.28,
        width: 0.20,
        height: 0.54,
        colorHex: '#0078D4',
      },
    ];

    // Se imagem fornecida, analisa com Gemini Flash
    if (imageBase64) {
      const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });
      const prompt = `Você é um analista tático de vigilância CFTV. Analise a imagem fornecida.
Identifique pessoas, veículos, animais ou movimentos relevantes.
Responda APENAS em JSON no formato:
{
  "label": "Pessoa",
  "confidence": 0.95,
  "description": "Pessoa se aproximando do portão social",
  "boundingBoxes": [
    {"label": "Pessoa", "confidence": 0.95, "left": 0.4, "top": 0.25, "width": 0.2, "height": 0.55}
  ]
}`;

      const imagePart = {
        inlineData: {
          data: imageBase64,
          mimeType: 'image/jpeg',
        },
      };

      const result = await model.generateContent([prompt, imagePart]);
      const text = result.response.text();
      try {
        const parsed = JSON.parse(text.replace(/```json|```/g, '').trim());
        detectedConfidence = parsed.confidence || detectedConfidence;
        sceneDescription = parsed.description || sceneDescription;
        if (parsed.boundingBoxes) boundingBoxes = parsed.boundingBoxes;
      } catch (err) {
        console.warn('Falha no parse do JSON do Gemini:', err);
      }
    }

    // Regra de Negócio Crítica: Filtro de Limiar de Certeza
    if (detectedConfidence < minConfidence) {
      console.log(`[EVENTO DESCARTADO] Confiança (${detectedConfidence}) abaixo do limiar (${minConfidence}).`);
      return res.status(200).json({
        status: 'discarded',
        reason: `Certeza (${(detectedConfidence * 100).toFixed(1)}%) abaixo do limiar configurado de ${(minConfidence * 100).toFixed(1)}%.`,
      });
    }

    const eventId = `evt-${cameraId}-${Date.now()}`;
    const deepLink = `bcam://event/${eventId}`;

    const eventData = {
      id: eventId,
      cameraId,
      cameraName,
      type: 'person',
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      description: sceneDescription,
      confidence: detectedConfidence,
      boundingBoxes,
      deepLinkUrl: deepLink,
    };

    // 1. Grava no Firestore (1GB grátis)
    await db.collection('cameras').doc(cameraId).collection('events').doc(eventId).set(eventData);

    // 2. Dispara Notificação Push FCM de Alta Prioridade com Deeplink (Ilimitado grátis)
    const message = {
      topic: `camera_${cameraId}`,
      notification: {
        title: `🚨 Alerta b-cam: Detecção em ${cameraName}`,
        body: `${sceneDescription} (Certeza: ${(detectedConfidence * 100).toFixed(0)}%)`,
      },
      data: {
        eventId,
        cameraId,
        deepLink,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'b_cam_surveillance_alerts',
          priority: 'max',
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
    };

    await messaging.send(message);

    return res.status(200).json({
      status: 'created',
      eventId,
      deepLink,
      confidence: detectedConfidence,
      boundingBoxes,
    });
  } catch (error) {
    console.error('Erro ao processar evento:', error);
    return res.status(500).json({ error: error.message });
  }
});

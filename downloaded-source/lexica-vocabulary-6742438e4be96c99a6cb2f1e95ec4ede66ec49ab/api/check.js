export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const apiKey = process.env.GROQ_API_KEY;
  if (!apiKey) {
    return res.status(500).json({ 
      error: 'API-ключ Groq не настроен в Environment Variables на Vercel.' 
    });
  }

  const { text } = req.body || {};
  if (!text || typeof text !== 'string' || !text.trim()) {
    return res.status(400).json({ error: 'Текст для проверки не передан.' });
  }

  try {
    const groqResponse = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: "openai/gpt-oss-120b",
        temperature: 0.2,
        response_format: { type: 'json_object' },
        messages: [
          {
            role: 'system',
            content: 'You are an expert English teacher. Analyze the user English text for grammar, spelling, punctuation, vocabulary, and style. Return valid JSON only with keys: cefr (string: A1, A2, B1, B2, C1, or C2), overall (short Russian summary of text quality), corrected (the full corrected English text), errors (array of objects with keys: original, correction, explanation in Russian), natural (how a native speaker would rephrase the idea naturally). If there are no errors, set errors to an empty array. Respond in valid JSON with no markdown formatting.'
          },
          {
            role: 'user',
            content: text.trim()
          }
        ]
      })
    });

    if (!groqResponse.ok) {
      const err = await groqResponse.json().catch(() => ({}));
      return res.status(groqResponse.status).json({ 
        error: err.error?.message || `Ошибка сервиса Groq (${groqResponse.status})` 
      });
    }

    const data = await groqResponse.json();
    const parsed = JSON.parse(data.choices?.[0]?.message?.content || '{}');
    return res.status(200).json(parsed);
  } catch (error) {
    console.error('API Check Error:', error);
    return res.status(500).json({ error: 'Внутренняя ошибка сервера при обращении к ИИ.' });
  }
}

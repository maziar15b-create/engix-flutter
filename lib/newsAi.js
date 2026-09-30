// ⚠️ فقط سمت سرور. نیاز به ANTHROPIC_API_KEY در متغیرهای محیطی سرور دارد.

const CATEGORY_KEYS = [
  "nezam", "exams", "insurance", "regulations",
  "materials", "civil", "education", "announcements",
];

export async function analyzeNewsArticle({ title, description }) {
  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) throw new Error("ANTHROPIC_API_KEY تنظیم نشده است.");

  const prompt = `متن زیر یک خبر خام است. فقط یک JSON خام و معتبر برگردان — بدون هیچ توضیح یا Markdown اضافه.

عنوان: ${title}
متن: ${(description || "").slice(0, 2000)}

خروجی باید دقیقاً این ساختار را داشته باشد:
{
  "summary": "خلاصه‌ی حرفه‌ای دو تا سه جمله‌ای به فارسی",
  "category_key": "یکی از: ${CATEGORY_KEYS.join(", ")}",
  "keywords": ["حداکثر ۵ کلمه کلیدی فارسی مرتبط"],
  "importance": "عددی بین ۱ (کم‌اهمیت) تا ۵ (بسیار مهم) — بر اساس تأثیر بر مهندسان، پیمانکاران و صنعت ساخت‌وساز",
  "is_relevant": "true اگر این خبر واقعاً به مهندسی، ساخت‌وساز، نظام مهندسی، مصالح، آزمون‌ها یا مقررات مرتبط است؛ در غیر این صورت false"
}`;

  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: "claude-sonnet-4-6",
      max_tokens: 500,
      messages: [{ role: "user", content: prompt }],
    }),
  });

  if (!res.ok) {
    throw new Error(`Anthropic API error: ${res.status} ${await res.text()}`);
  }

  const data = await res.json();
  const text = (data.content || []).map((b) => b.text || "").join("").trim();
  const cleaned = text.replace(/^```json\s*|```$/g, "").trim();

  let parsed;
  try {
    parsed = JSON.parse(cleaned);
  } catch (e) {
    throw new Error("پاسخ AI قابل parse نبود: " + text.slice(0, 200));
  }

  return {
    summary: String(parsed.summary || "").slice(0, 1000),
    category_key: CATEGORY_KEYS.includes(parsed.category_key) ? parsed.category_key : "civil",
    keywords: Array.isArray(parsed.keywords) ? parsed.keywords.slice(0, 5).map(String) : [],
    importance: Math.min(5, Math.max(1, parseInt(parsed.importance, 10) || 1)),
    isRelevant: parsed.is_relevant !== false,
  };
}

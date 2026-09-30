const BITPAY_API_BASE = "https://bitpay.ir/payment";

function apiKey() {
  return (process.env.BITPAY_API_KEY || "").trim();
}

export async function requestPayment(amount, description, callbackUrl, meta = {}) {
  try {
    const key = apiKey();
    if (!key) {
      return { success: false, error: "BITPAY_API_KEY روی سرور تنظیم نشده است." };
    }

    const params = new URLSearchParams({
      api: key,
      amount: String(amount),
      redirect: callbackUrl,
      factorId: meta.factorId || "",
      name: meta.name || "",
      email: meta.email || "",
      description: description || "",
    });

    const res = await fetch(`${BITPAY_API_BASE}/gateway-send`, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: params.toString(),
    });

    const text = (await res.text()).trim();
    const trackId = Number(text);

    if (!trackId || trackId <= 0) {
      return { success: false, error: `پاسخ خام بیت‌پی: ${text}` };
    }

    return {
      success: true,
      authority: String(trackId),
      paymentUrl: `${BITPAY_API_BASE}/gateway-${trackId}-get`,
    };
  } catch (e) {
    return { success: false, error: e.message };
  }
}

export async function verifyPayment(trackId, idGet) {
  try {
    const params = new URLSearchParams({
      api: apiKey(),
      trackId: String(trackId),
      idGet: String(idGet),
      jsonType: "1",
    });

    const res = await fetch(`${BITPAY_API_BASE}/gateway-result-second`, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: params.toString(),
    });

    const json = await res.json();
    if (json && Number(json.status) === 1) {
      return { success: true, amount: json.amount, cardNumber: json.cardNumber };
    }
    return { success: false, error: `پاسخ خام بیت‌پی: ${JSON.stringify(json)}` };
  } catch (e) {
    return { success: false, error: e.message };
  }
}

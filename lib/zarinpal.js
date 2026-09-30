// اتصال به درگاه پرداخت زرین‌پال
// مستندات: https://docs.zarinpal.com

const MERCHANT_ID = process.env.ZARINPAL_MERCHANT_ID;
const SANDBOX = process.env.ZARINPAL_SANDBOX === "true";

const BASE_URL = SANDBOX
  ? "https://sandbox.zarinpal.com/pg/v4/payment"
  : "https://payment.zarinpal.com/pg/v4/payment";

const STARTPAY_URL = SANDBOX
  ? "https://sandbox.zarinpal.com/pg/StartPay/"
  : "https://www.zarinpal.com/pg/StartPay/";

export async function requestPayment(amount, description, callbackUrl, meta = {}) {
  const res = await fetch(`${BASE_URL}/request.json`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      merchant_id: MERCHANT_ID,
      amount,
      description,
      callback_url: callbackUrl,
      metadata: { mobile: meta.mobile, email: meta.email },
    }),
  });
  const json = await res.json();
  const data = json.data;

  if (data && data.code === 100) {
    return { success: true, authority: data.authority, paymentUrl: `${STARTPAY_URL}${data.authority}` };
  }
  return { success: false, error: (json.errors && json.errors.message) || "خطا در اتصال به درگاه پرداخت" };
}

export async function verifyPayment(amount, authority) {
  const res = await fetch(`${BASE_URL}/verify.json`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ merchant_id: MERCHANT_ID, amount, authority }),
  });
  const json = await res.json();
  const data = json.data;

  if (data && (data.code === 100 || data.code === 101)) {
    return { success: true, refId: data.ref_id };
  }
  return { success: false, error: (json.errors && json.errors.message) || "پرداخت تایید نشد" };
}

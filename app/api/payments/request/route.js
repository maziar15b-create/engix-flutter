import { NextResponse } from "next/server";
import { getSupabaseAdmin } from "../../../../lib/supabaseAdmin";
import { requestPayment as requestZarinpal } from "../../../../lib/zarinpal";
import { requestPayment as requestBitpay } from "../../../../lib/bitpay";

// هزینه‌های ثابت برای انواعی که فرق نمی‌کنند
const FEES = {
  job_post: 150,
  ad: 1000000,
};

// هزینه‌ی آگهی کاریابی به نوع آگهی بستگی دارد (ریال)
const JOB_LISTING_FEES = {
  job_seeking: 1000000, // درخواست کار
  hiring: 1500000, // درخواست نیرو
};

const TABLE_BY_TYPE = {
  job_listing: "job_listings",
  job_post: "job_posts",
  ad: "ads",
};

export async function POST(req) {
  try {
    const { itemType, itemId, mobile, email, description, gateway } = await req.json();

    if (!itemType || !itemId || !TABLE_BY_TYPE[itemType]) {
      return NextResponse.json({ error: "اطلاعات درخواست ناقص یا نامعتبر است." }, { status: 400 });
    }

    // شناسه‌ی کاربر دیگر از بدنه‌ی درخواست خوانده نمی‌شود (قابل جعل بود)؛
    // به‌جایش از نشستِ احرازهویت‌شده استخراج می‌شود.
    const authHeader = req.headers.get("authorization") || "";
    const token = authHeader.replace(/^Bearer\s+/i, "");
    if (!token) {
      return NextResponse.json({ error: "احراز هویت لازم است." }, { status: 401 });
    }

    const selectedGateway = gateway === "bitpay" ? "bitpay" : "zarinpal";
    const supabaseAdmin = getSupabaseAdmin();

    const { data: userData, error: userError } = await supabaseAdmin.auth.getUser(token);
    if (userError || !userData?.user) {
      return NextResponse.json({ error: "نشست نامعتبر است." }, { status: 401 });
    }
    const userId = userData.user.id;

    const table = TABLE_BY_TYPE[itemType];
    const ownerColumn = itemType === "ad" ? "created_by" : itemType === "job_post" ? "posted_by" : "author_id";

    // برای آگهی کاریابی، listing_type رو هم می‌خوانیم تا مبلغ درست محاسبه بشه
    const selectCols = itemType === "job_listing" ? "id, listing_type" : "id";
    const { data: item, error: itemErr } = await supabaseAdmin
      .from(table)
      .select(selectCols)
      .eq("id", itemId)
      .eq(ownerColumn, userId)
      .maybeSingle();

    if (itemErr || !item) {
      return NextResponse.json({ error: "آیتم مورد نظر پیدا نشد." }, { status: 404 });
    }

    let amount;
    if (itemType === "job_listing") {
      amount = JOB_LISTING_FEES[item.listing_type];
      if (!amount) {
        return NextResponse.json({ error: "نوع آگهی نامعتبر است." }, { status: 400 });
      }
    } else {
      amount = FEES[itemType];
    }

    const { data: payment, error: payErr } = await supabaseAdmin
      .from("payments")
      .insert({ user_id: userId, item_type: itemType, item_id: itemId, amount, status: "pending", gateway: selectedGateway })
      .select()
      .single();
    if (payErr) throw new Error(payErr.message);

    const callbackUrl = `${process.env.NEXT_PUBLIC_APP_URL}/api/payments/verify?paymentId=${payment.id}&gateway=${selectedGateway}`;

    const result =
      selectedGateway === "bitpay"
        ? await requestBitpay(amount, description || "هزینه ثبت آگهی", callbackUrl, { mobile, email, factorId: payment.id })
        : await requestZarinpal(amount, description || "هزینه ثبت آگهی", callbackUrl, { mobile, email });

    if (!result.success) {
      await supabaseAdmin.from("payments").update({ status: "failed" }).eq("id", payment.id);
      return NextResponse.json({ error: result.error }, { status: 400 });
    }

    await supabaseAdmin.from("payments").update({ authority: result.authority }).eq("id", payment.id);

    return NextResponse.json({ paymentUrl: result.paymentUrl });
  } catch (e) {
    return NextResponse.json({ error: e.message }, { status: 400 });
  }
}

import { NextResponse } from "next/server";
import { getSupabaseAdmin } from "../../../../lib/supabaseAdmin";
import { verifyPayment as verifyZarinpal } from "../../../../lib/zarinpal";
import { verifyPayment as verifyBitpay } from "../../../../lib/bitpay";

const TABLE_BY_TYPE = {
  job_listing: "job_listings",
  job_post: "job_posts",
  ad: "ads",
};

function activationPatch(itemType) {
  if (itemType === "ad") return { active: true };
  if (itemType === "job_post") return { status: "open" };
  return { status: "active" };
}

export async function GET(req) {
  const url = new URL(req.url);
  const paymentId = url.searchParams.get("paymentId");
  const appUrl = process.env.NEXT_PUBLIC_APP_URL;

  try {
    const supabaseAdmin = getSupabaseAdmin();
    const { data: payment, error } = await supabaseAdmin
      .from("payments")
      .select("*")
      .eq("id", paymentId)
      .single();
    if (error || !payment) {
      return NextResponse.redirect(`${appUrl}/?payment=error`);
    }

    // Idempotency: اگر این پرداخت قبلاً با موفقیت verify شده، دوباره درگاه را صدا نمی‌زنیم
    // (جلوگیری از verify دوباره در اثر رفرش صفحه‌ی callback یا فراخوانی تکراری)
    if (payment.status === "paid") {
      return NextResponse.redirect(`${appUrl}/?payment=success&ref=${payment.ref_id || ""}`);
    }

    const gateway = payment.gateway === "bitpay" ? "bitpay" : "zarinpal";
    let result;
    let refId;

    if (gateway === "bitpay") {
      // بیت‌پی این پارامترها رو به آدرس ریدایرکت اضافه می‌کنه: trackId, id_get, status
      const idGet = url.searchParams.get("id_get") || url.searchParams.get("idGet");
      const bpStatus = url.searchParams.get("status");
      const trackId = url.searchParams.get("trackId") || payment.authority;

      if (bpStatus !== "1" && bpStatus !== "success") {
        await supabaseAdmin.from("payments").update({ status: "failed" }).eq("id", payment.id);
        return NextResponse.redirect(`${appUrl}/?payment=cancelled`);
      }

      result = await verifyBitpay(trackId, idGet);
      refId = trackId;
    } else {
      const authority = url.searchParams.get("Authority");
      const status = url.searchParams.get("Status");

      if (status !== "OK") {
        await supabaseAdmin.from("payments").update({ status: "failed" }).eq("id", payment.id);
        return NextResponse.redirect(`${appUrl}/?payment=cancelled`);
      }

      result = await verifyZarinpal(payment.amount, authority);
      refId = result.refId;
    }

    if (!result.success) {
      await supabaseAdmin.from("payments").update({ status: "failed" }).eq("id", payment.id);
      return NextResponse.redirect(`${appUrl}/?payment=failed`);
    }

    await supabaseAdmin
      .from("payments")
      .update({ status: "paid", ref_id: refId })
      .eq("id", payment.id);

    const table = TABLE_BY_TYPE[payment.item_type];
    await supabaseAdmin.from(table).update(activationPatch(payment.item_type)).eq("id", payment.item_id);

    return NextResponse.redirect(`${appUrl}/?payment=success&ref=${refId}`);
  } catch (e) {
    return NextResponse.redirect(`${appUrl}/?payment=error`);
  }
}

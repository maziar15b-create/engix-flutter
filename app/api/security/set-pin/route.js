import { NextResponse } from "next/server";
import crypto from "crypto";
import { getSupabaseAdmin } from "../../../../lib/supabaseAdmin";

export async function POST(req) {
  try {
    const authHeader = req.headers.get("authorization") || "";
    const token = authHeader.replace(/^Bearer\s+/i, "");
    if (!token) return NextResponse.json({ error: "احراز هویت لازم است." }, { status: 401 });

    const supabaseAdmin = getSupabaseAdmin();
    const { data: userData, error: userErr } = await supabaseAdmin.auth.getUser(token);
    if (userErr || !userData?.user) return NextResponse.json({ error: "نشست نامعتبر است." }, { status: 401 });

    const { pin } = await req.json();

    let hash = null;
    if (pin) {
      if (!/^\d{4,8}$/.test(pin)) {
        return NextResponse.json({ error: "رمز باید بین ۴ تا ۸ رقم باشد." }, { status: 400 });
      }
      hash = crypto.createHash("sha256").update(pin).digest("hex");
    }

    const { error } = await supabaseAdmin
      .from("profiles")
      .update({ two_factor_pin_hash: hash })
      .eq("id", userData.user.id);
    if (error) throw new Error(error.message);

    return NextResponse.json({ success: true, enabled: !!hash });
  } catch (e) {
    return NextResponse.json({ error: e.message }, { status: 400 });
  }
}

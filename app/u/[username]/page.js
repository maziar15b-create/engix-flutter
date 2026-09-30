import { createClient } from "@supabase/supabase-js";
import { ROLE_LABELS } from "../../../lib/ids";

export const dynamic = "force-dynamic";

async function getProfile(username) {
  const supabase = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL, process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY);
  const { data } = await supabase
    .from("profiles")
    .select("name, avatar_url, code, field, roles, bio, username")
    .eq("username", username)
    .maybeSingle();
  return data;
}

export default async function PublicProfilePage({ params }) {
  const profile = await getProfile(params.username);

  if (!profile) {
    return (
      <div dir="rtl" style={{ padding: 40, textAlign: "center", fontFamily: "sans-serif" }}>
        کاربری با این آیدی پیدا نشد.
      </div>
    );
  }

  return (
    <div dir="rtl" style={{ padding: 24, maxWidth: 420, margin: "0 auto", fontFamily: "sans-serif" }}>
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 12, marginTop: 30 }}>
        {profile.avatar_url ? (
          <img loading="lazy" decoding="async" src={profile.avatar_url} alt="" style={{ width: 96, height: 96, borderRadius: "50%", objectFit: "cover" }} />
        ) : (
          <div style={{ width: 96, height: 96, borderRadius: "50%", background: "#0A1F3D", color: "#FF6B35", display: "flex", alignItems: "center", justifyContent: "center", fontWeight: 700, fontSize: 32 }}>
            {profile.name ? profile.name[0] : "?"}
          </div>
        )}
        <div style={{ fontWeight: 800, fontSize: 20 }}>{profile.name}</div>
        <div style={{ color: "#888", fontSize: 14 }}>@{profile.username}</div>
        <div style={{ color: "#888", fontSize: 13 }}>{profile.field}</div>
        {profile.bio && <div style={{ fontSize: 14, textAlign: "center", marginTop: 8, lineHeight: 1.8 }}>{profile.bio}</div>}
        <div style={{ display: "flex", gap: 6, flexWrap: "wrap", justifyContent: "center", marginTop: 8 }}>
          {(profile.roles || []).map((r) => (
            <span key={r} style={{ fontSize: 12, background: "#eee", padding: "4px 10px", borderRadius: 20 }}>
              {ROLE_LABELS[r] || r}
            </span>
          ))}
        </div>
      </div>
    </div>
  );
}

import { XMLParser } from "fast-xml-parser";

export async function fetchRssItems(rssUrl, limit = 8) {
  const res = await fetch(rssUrl, {
    headers: { "User-Agent": "EngiX-NewsBot/1.0" },
    signal: AbortSignal.timeout(15000),
  });
  if (!res.ok) throw new Error(`RSS fetch failed (${res.status}): ${rssUrl}`);
  const xml = await res.text();

  const parser = new XMLParser({ ignoreAttributes: false, attributeNamePrefix: "@_" });
  const parsed = parser.parse(xml);

  const rawItems =
    parsed?.rss?.channel?.item ||
    parsed?.feed?.entry ||
    [];
  const items = Array.isArray(rawItems) ? rawItems : [rawItems];

  return items.slice(0, limit).map((it) => {
    const link =
      typeof it.link === "string" ? it.link :
      it.link?.["@_href"] || it.link?.[0]?.["@_href"] || "";
    return {
      title: stripHtml(it.title),
      description: stripHtml(it.description || it.summary || it["content:encoded"]),
      link: link || it.guid || "",
      publishedAt: it.pubDate || it.published || it.updated || null,
    };
  }).filter((i) => i.title && i.link);
}

function stripHtml(value) {
  if (!value) return "";
  const str = typeof value === "string" ? value : (value["#text"] || "");
  return str.replace(/<[^>]*>/g, "").trim();
}

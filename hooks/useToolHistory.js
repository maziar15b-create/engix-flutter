"use client";
import { useState, useCallback } from "react";
import { supabase } from "../lib/supabaseClient";

/**
 * هوک عمومی سابقه/ذخیره‌سازی برای ابزارها — هر ابزاری (متره، لیستوفر،
 * طراحی تیر و...) می‌تواند وضعیت فعلی خودش را (به‌شکل یک آبجکت
 * قابل‌تبدیل به JSON) با یک عنوان دلخواه ذخیره کند، بعداً از لیست
 * سابقه بازش کند و ادامه دهد، یا حذفش کند.
 */
export function useToolHistory(toolId, userId) {
  const [items, setItems] = useState(null); // null = هنوز لود نشده
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const loadList = useCallback(async () => {
    if (!userId || !toolId) return;
    setLoading(true);
    setError("");
    try {
      const { data, error: err } = await supabase
        .from("tool_saves")
        .select("id, title, updated_at")
        .eq("user_id", userId)
        .eq("tool_id", toolId)
        .order("updated_at", { ascending: false });
      if (err) throw err;
      setItems(data || []);
    } catch (e) {
      setError(e.message);
      setItems([]);
    } finally {
      setLoading(false);
    }
  }, [toolId, userId]);

  const saveNew = useCallback(
    async (title, data) => {
      if (!userId || !toolId) return null;
      const { data: row, error: err } = await supabase
        .from("tool_saves")
        .insert({ user_id: userId, tool_id: toolId, title: title || "بدون عنوان", data })
        .select()
        .single();
      if (err) throw err;
      return row;
    },
    [toolId, userId]
  );

  const updateExisting = useCallback(async (id, title, data) => {
    const { error: err } = await supabase
      .from("tool_saves")
      .update({ title, data, updated_at: new Date().toISOString() })
      .eq("id", id);
    if (err) throw err;
  }, []);

  const loadOne = useCallback(async (id) => {
    const { data, error: err } = await supabase.from("tool_saves").select("*").eq("id", id).maybeSingle();
    if (err) throw err;
    return data;
  }, []);

  const removeOne = useCallback(async (id) => {
    const { error: err } = await supabase.from("tool_saves").delete().eq("id", id);
    if (err) throw err;
    setItems((prev) => (prev ? prev.filter((i) => i.id !== id) : prev));
  }, []);

  return { items, loading, error, loadList, saveNew, updateExisting, loadOne, removeOne };
}

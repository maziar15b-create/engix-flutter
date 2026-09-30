"use client";
import { useEffect } from "react";
import { logError } from "../lib/logger";

export default function Error({ error, reset }) {
  useEffect(() => {
    logError({ message: error?.message, stack: error?.stack });
  }, [error]);

  return (
    <div style={{ padding: 20, fontFamily: "monospace", direction: "ltr", textAlign: "left" }}>
      <h2>خطا رخ داد:</h2>
      <pre style={{ whiteSpace: "pre-wrap", color: "red", fontSize: 12 }}>
        {error?.message}
        {"\n\n"}
        {error?.stack}
      </pre>
      <button onClick={() => reset()}>تلاش دوباره</button>
    </div>
  );
}

"use client";
import { useEffect } from "react";
import { logError } from "../lib/logger";

export default function GlobalError({ error, reset }) {
  useEffect(() => {
    logError({ message: error?.message, stack: error?.stack, level: "fatal" });
  }, [error]);

  return (
    <html dir="rtl">
      <body style={{ padding: 20, fontFamily: "monospace" }}>
        <h2>خطای بحرانی رخ داد</h2>
        <pre style={{ whiteSpace: "pre-wrap", color: "red", fontSize: 12, textAlign: "left" }}>
          {error?.message}
        </pre>
        <button onClick={() => reset()}>تلاش دوباره</button>
      </body>
    </html>
  );
}

"use client";
import { Component } from "react";

/**
 * اگر در رندر بخش پیام‌رسان یک خطای جاوااسکریپت رخ بدهد، به‌جای اینکه
 * صفحه به‌صورت نامشخص/نصفه‌نیمه (ترکیبی از UI قدیمی و جدید) بماند، این
 * Error Boundary خطا را می‌گیرد و یک پیام واضح با متن دقیق خطا نشان
 * می‌دهد. این برای پیدا کردن ریشه‌ی باگ‌هایی که فقط با «مشاهده‌ی ظاهر
 * خراب» قابل تشخیص نبودند حیاتی است.
 */
export default class MessengerErrorBoundary extends Component {
  constructor(props) {
    super(props);
    this.state = { error: null };
  }

  static getDerivedStateFromError(error) {
    return { error };
  }

  componentDidCatch(error, info) {
    console.error("Messenger crashed:", error, info);
  }

  render() {
    if (this.state.error) {
      return (
        <div
          style={{
            padding: 20,
            direction: "ltr",
            textAlign: "left",
            background: "#1A0508",
            border: "1px solid #E5484D",
            borderRadius: 10,
            color: "#F5F4FA",
            fontFamily: "monospace",
            fontSize: 12,
            whiteSpace: "pre-wrap",
            wordBreak: "break-word",
            maxHeight: "70vh",
            overflowY: "auto",
          }}
        >
          <div style={{ color: "#FF6B6B", fontWeight: 700, marginBottom: 10, fontSize: 14 }}>
            خطای پیام‌رسان (لطفاً این متن را کامل کپی و ارسال کنید):
          </div>
          <div>{String(this.state.error && this.state.error.message)}</div>
          <div style={{ marginTop: 10, opacity: 0.7 }}>{String(this.state.error && this.state.error.stack)}</div>
          <button
            onClick={() => this.setState({ error: null })}
            style={{
              marginTop: 16, padding: "8px 16px", background: "#C50337", color: "#fff",
              border: "none", borderRadius: 8, cursor: "pointer", fontFamily: "inherit",
            }}
          >
            تلاش دوباره
          </button>
        </div>
      );
    }
    return this.props.children;
  }
}

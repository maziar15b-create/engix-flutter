import { Vazirmatn } from "next/font/google";
import "./globals.css";
import NativeAppInit from "../components/NativeAppInit";
import { LanguageProvider } from "../lib/i18n/LanguageContext";

const vazir = Vazirmatn({
  subsets: ["arabic", "latin"],
  variable: "--font-vazir",
  display: "swap",
});

export const metadata = {
  title: "EngiX — شبکه مهندسان",
  description: "پلتفرم مهندسان عمران: پروژه‌ها، پیام‌رسان و آموزش",
  manifest: "/manifest.json",
  themeColor: "#0A1F3D",
  icons: {
    icon: "/icons/IMG_5709.png",
    apple: "/icons/IMG_5709.png",
  },
};

// جلوگیری از زوم با پینچ/دابل‌تپ روی موبایل — بدون این تنظیم، مرورگر
// اجازه‌ی بزرگ‌نمایی صفحه را می‌دهد که حس «سایت» به‌جای «اپلیکیشن» می‌دهد.
// این export مخصوص Next.js App Router است (جایگزین متا‌تگ viewport دستی).
export const viewport = {
  width: "device-width",
  initialScale: 1,
  maximumScale: 1,
  userScalable: false,
  viewportFit: "cover",
};

export default function RootLayout({ children }) {
  // مقدار پیش‌فرض روی <html> برای سازگاری با SSR است (زبان پیش‌فرض: فارسی).
  // LanguageProvider بعد از mount شدن، lang/dir واقعی کاربر را از localStorage اعمال می‌کند.
  return (
    <html lang="fa" dir="rtl" className={vazir.variable}>
      <body>
        <LanguageProvider>
          <NativeAppInit />
          {children}
        </LanguageProvider>
      </body>
    </html>
  );
}

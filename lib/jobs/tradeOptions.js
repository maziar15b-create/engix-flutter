export var jobTypes = [
  { key: "hire_engineer", label: "درخواست کار مهندس" },
  { key: "hire_contractor", label: "درخواست پیمانکار" },
  { key: "hire_worker", label: "درخواست نیروی اجرایی" },
  { key: "project", label: "استخدام برای پروژه" }
];

export var tradeOptions = [
  "بنا",
  "جوشکار",
  "برقکار",
  "لوله‌کش",
  "قالب‌بند",
  "آرماتوربند",
  "گچکار",
  "راننده ماشین‌آلات",
  "کارگر ساده"
];

export function jobTypeLabel(key) {
  for (var i = 0; i < jobTypes.length; i++) {
    if (jobTypes[i].key === key) return jobTypes[i].label;
  }
  return key;
}

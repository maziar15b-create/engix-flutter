import { civilTools } from "./civilCalcs";
import { architectureTools } from "./architectureCalcs";
import { electricalTools } from "./electricalCalcs";
import { mechanicalTools } from "./mechanicalCalcs";
import { mechanicalEngTools } from "./mechanicalEngCalcs";
import { surveyingTools } from "./surveyingCalcs";
import { roofTools } from "./roofCalcs";
import { asphaltTools } from "./asphaltCalcs";
import { steelProfileTools } from "./steelProfileCalcs";
import { foundationTools } from "./foundationCalcs";
import { lsfTools } from "./lsfCalcs";
import { generalTools } from "./generalCalcs";
import { structuralDesignTools } from "./structuralDesignCalcs";

// این ابزارها ماهیتاً کار «دفتر فنی» هستند (متره و برآورد، شاپ‌درائینگ و...)
// و قبلاً داخل «ابزارهای عمران» تعریف شده بودند. اینجا از همان civilTools
// جدا (filter) می‌شوند تا در یک دسته‌ی مستقل «دفتر فنی» نمایش داده شوند،
// بدون این‌که نیاز باشد civilCalcs.js را دوباره‌نویسی یا تکرار کنیم.
var TECH_OFFICE_IDS = ["quantity-takeoff", "rebar-shop-drawing", "lean-concrete-rubble", "progress-payment", "overhead-coefficients", "price-adjustment", "delay-penalty"];

var technicalOfficeTools = civilTools.filter(function (t) {
  return TECH_OFFICE_IDS.indexOf(t.id) !== -1;
});

var civilToolsWithoutTechOffice = civilTools.filter(function (t) {
  return TECH_OFFICE_IDS.indexOf(t.id) === -1;
});

export var categories = [
  {
    id: "technical-office",
    name: "دفتر فنی",
    icon: "📋",
    tools: technicalOfficeTools
  },
  {
    id: "civil",
    name: "ابزارهای عمران",
    icon: "🏗️",
    tools: [
      ...civilToolsWithoutTechOffice,
      ...foundationTools,
      ...roofTools,
      ...asphaltTools,
      ...steelProfileTools,
      ...lsfTools,
    ]
  },
  {
    id: "structural-design",
    name: "طراحی سازه",
    icon: "🏢",
    tools: structuralDesignTools
  },
  {
    id: "architecture",
    name: "معماری",
    icon: "🏛",
    tools: architectureTools
  },
  {
    id: "electrical",
    name: "برق",
    icon: "⚡",
    tools: electricalTools
  },
  {
    id: "installations",
    name: "تأسیسات",
    icon: "❄️",
    tools: mechanicalTools
  },
  {
    id: "mechanical",
    name: "مکانیک",
    icon: "⚙️",
    tools: mechanicalEngTools
  },
  {
    id: "surveying",
    name: "نقشه‌برداری",
    icon: "📐",
    tools: surveyingTools
  },
  {
    id: "general",
    name: "ابزارهای عمومی",
    icon: "📏",
    tools: generalTools
  }
];

export function findToolById(toolId) {
  for (var i = 0; i < categories.length; i++) {
    var cat = categories[i];
    for (var j = 0; j < cat.tools.length; j++) {
      if (cat.tools[j].id === toolId) {
        return cat.tools[j];
      }
    }
  }
  return null;
}

export function findCategoryById(categoryId) {
  for (var i = 0; i < categories.length; i++) {
    if (categories[i].id === categoryId) {
      return categories[i];
    }
  }
  return null;
}

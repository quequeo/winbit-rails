export type PeriodOption = {
  value: string;
  label: string;
  start: string;
  end: string;
};

export const toLocalIsoDate = (date: Date) => {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
};

const monthNames = [
  "Ene",
  "Feb",
  "Mar",
  "Abr",
  "May",
  "Jun",
  "Jul",
  "Ago",
  "Sep",
  "Oct",
  "Nov",
  "Dic",
];

const buildMonthOption = (year: number, month: number): PeriodOption => {
  const lastDay = new Date(year, month, 0).getDate();
  const start = `${year}-${String(month).padStart(2, "0")}-01`;
  const end = `${year}-${String(month).padStart(2, "0")}-${String(lastDay).padStart(2, "0")}`;
  return {
    value: `${start}|${end}`,
    label: `${monthNames[month - 1]} ${year}`,
    start,
    end,
  };
};

const buildQuarterOption = (year: number, quarter: number): PeriodOption => {
  const sm = (quarter - 1) * 3 + 1;
  const em = quarter * 3;
  const start = `${year}-${String(sm).padStart(2, "0")}-01`;
  const lastDay = new Date(year, em, 0).getDate();
  const end = `${year}-${String(em).padStart(2, "0")}-${String(lastDay).padStart(2, "0")}`;
  return {
    value: `${start}|${end}`,
    label: `Q${quarter} ${year}`,
    start,
    end,
  };
};

export const buildMonthOptions = (now = new Date()): PeriodOption[] => {
  const opts: PeriodOption[] = [];
  const todayIso = toLocalIsoDate(now);
  const lastDayThisMonth = new Date(
    now.getFullYear(),
    now.getMonth() + 1,
    0,
  ).getDate();
  const thisMonthEnd = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-${String(lastDayThisMonth).padStart(2, "0")}`;

  let cursor = new Date(now.getFullYear(), now.getMonth(), 1);
  if (todayIso < thisMonthEnd) {
    cursor = new Date(now.getFullYear(), now.getMonth() - 1, 1);
  }

  for (let i = 0; i < 12; i++) {
    const d = new Date(cursor.getFullYear(), cursor.getMonth() - i, 1);
    opts.push(buildMonthOption(d.getFullYear(), d.getMonth() + 1));
  }

  return opts;
};

export const buildQuarterOptions = (now = new Date()): PeriodOption[] => {
  const opts: PeriodOption[] = [];
  const todayIso = toLocalIsoDate(now);
  const curQ = Math.floor(now.getMonth() / 3) + 1;
  let y = now.getFullYear();
  let q = curQ;

  const curOption = buildQuarterOption(y, q);
  if (todayIso < curOption.end) {
    q = curQ - 1;
    if (q <= 0) {
      q = 4;
      y -= 1;
    }
  }

  for (let i = 0; i < 8; i++) {
    let qy = y;
    let qq = q - i;
    while (qq <= 0) {
      qq += 4;
      qy -= 1;
    }
    opts.push(buildQuarterOption(qy, qq));
  }

  return opts;
};

export const buildSemesterOptions = (now = new Date()): PeriodOption[] => {
  const opts: PeriodOption[] = [];
  const todayIso = toLocalIsoDate(now);
  const year = now.getFullYear();
  const h1End = `${year}-06-30`;
  const h2End = `${year}-12-31`;

  let startYear = year;
  let startSemester: 1 | 2 = 2;

  if (todayIso >= h2End) {
    startSemester = 2;
  } else if (todayIso >= h1End) {
    startSemester = 1;
  } else {
    startYear = year - 1;
    startSemester = 2;
  }

  for (let i = 0; i < 4; i++) {
    let sy = startYear;
    let ss: 1 | 2 = startSemester;
    for (let j = 0; j < i; j++) {
      ss = ss === 1 ? 2 : 1;
      if (ss === 2) sy -= 1;
    }

    const sm = ss === 1 ? 1 : 7;
    const em = ss === 1 ? 6 : 12;
    const start = `${sy}-${String(sm).padStart(2, "0")}-01`;
    const lastDay = new Date(sy, em, 0).getDate();
    const end = `${sy}-${String(em).padStart(2, "0")}-${String(lastDay).padStart(2, "0")}`;
    const label = ss === 1 ? `1er Sem ${sy}` : `2do Sem ${sy}`;
    opts.push({ value: `${start}|${end}`, label, start, end });
  }

  return opts;
};

export const buildYearOptions = (now = new Date()): PeriodOption[] => {
  const opts: PeriodOption[] = [];
  const todayIso = toLocalIsoDate(now);
  const year = now.getFullYear();
  const firstYear = todayIso >= `${year}-12-31` ? year : year - 1;

  for (let i = 0; i < 3; i++) {
    const y = firstYear - i;
    const start = `${y}-01-01`;
    const end = `${y}-12-31`;
    opts.push({ value: `${start}|${end}`, label: `${y}`, start, end });
  }

  return opts;
};

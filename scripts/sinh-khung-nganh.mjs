#!/usr/bin/env node
/**
 * Sinh `KhungNganh.swift` từ dữ liệu ngành của web — khối → ngành → ngành hẹp
 * → khung 9 kỳ, cộng tên môn, "học xong làm gì" và gợi ý từng môn.
 *
 *     /Users/admin/Downloads/api-backend/node_modules/.bin/tsx \
 *       --tsconfig /Users/admin/Downloads/api-backend/frontend/tsconfig.json \
 *       scripts/sinh-khung-nganh.mjs
 *
 * ⚠️ CHẠY MÃ CỦA WEB, KHÔNG BÓC CHỮ. Khung của khối CNTT không nằm sẵn trong
 * file — `semesterPlan()` điền môn của combo vào các ô `SE_COM*1`… lúc chạy.
 * Bóc bằng regex là được khung THIẾU môn chuyên ngành, và thiếu kiểu đó hỏng
 * câm: app vẫn chạy, chỉ ít môn hơn web.
 *
 * Web đổi khung / thêm ngành thì chạy lại script này. App KHÔNG tự thấy.
 */
import { writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const WEB = process.env.WEB_ROOT || '/Users/admin/Downloads/api-backend/frontend/src';
const nap = (p) => import(path.join(WEB, p));

const { CATALOG, leafSemesterPlan } = await nap('data/academyCatalog.ts');
const { isPlaceholderCode, subjectName } = await nap('data/fptuSubjects.ts');
const { CAREER_OUTCOMES, COURSE_HINTS } = await nap('data/academyRoadmap.ts');
const { MA_CU_THAY_THE } = await nap('components/academy/locTheoNganh.ts');

const khung = {};
const tenMon = {};
const ghi = (f, m, c) => {
  const plan = leafSemesterPlan(f, m, c).map(({ semester, codes }) => ({
    ky: semester,
    ma: [...new Set(codes.filter((x) => !isPlaceholderCode(x)).map((x) => x.trim()))],
  }));
  if (!plan.length) return 0;
  khung[`${f}|${m}|${c ?? ''}`] = plan;
  const tat = new Set();
  for (const k of plan) for (const x of k.ma) {
    tat.add(x.toUpperCase());
    const t = subjectName(x);
    if (t) tenMon[x.toUpperCase()] = t;
  }
  return tat.size;
};

const khoi = CATALOG.map((f) => ({
  id: f.id, nameVi: f.nameVi, name: f.name, icon: f.icon,
  majors: f.majors.map((m) => {
    // Khối CNTT có khung NỀN cho ngành chưa chọn combo; khối khác thì không.
    const soMonNen = ghi(f.id, m.id, null);
    return {
      id: m.id, nameVi: m.nameVi, name: m.name, icon: m.icon,
      comboNote: m.comboNote ?? null,
      curriculumCode: m.curriculumCode ?? null,
      curriculumId: m.curriculumId ?? null,
      credits: m.credits ?? null,
      soMonNen,
      combos: m.combos.map((c) => ({
        id: c.id, code: c.code ?? null, nameVi: c.nameVi, name: c.name, icon: c.icon,
        soMon: ghi(f.id, m.id, c.id),
      })),
    };
  }),
}));

const goi = {
  khoi, khung, tenMon,
  ngheNghiep: CAREER_OUTCOMES,
  goiYMon: COURSE_HINTS,
  maCuThayThe: MA_CU_THAY_THE,
};

// ── Chốt: đếm để thấy ngay khi web đổi mà bộ sinh đọc thiếu ──
const soNganhHep = khoi.reduce((a, f) => a + f.majors.reduce((b, m) => b + m.combos.length, 0), 0);
const hongKhung = khoi.flatMap((f) => f.majors.flatMap((m) =>
  m.combos.filter((c) => c.soMon === 0).map((c) => `${f.id}/${m.id}/${c.id}`)));
const json = JSON.stringify(goi);
if (json.includes('"""#')) throw new Error('JSON chứa `"""#` — sẽ làm vỡ chuỗi thô của Swift');

const dich = path.resolve(path.dirname(fileURLToPath(import.meta.url)),
  '../CuongThaiApp/Shared/Academy/KhungNganh.swift');
writeFileSync(dich, `// ⚠️ TỆP SINH BẰNG MÁY — đừng sửa tay. Chạy lại scripts/sinh-khung-nganh.mjs.
// Nguồn: frontend/src/data/academyCatalog.ts (+ fptuCurriculum, fptuFaculties,
// fptuSubjects, academyRoadmap) và components/academy/locTheoNganh.ts của web.
// ${khoi.length} khối · ${khoi.reduce((a, f) => a + f.majors.length, 0)} ngành · ${soNganhHep} ngành hẹp · ${Object.keys(khung).length} khung · ${Object.keys(tenMon).length} tên môn

let khungNganhJSON = #"""
${json}
"""#
`);

console.log(`✓ ${dich}`);
console.log(`  ${khoi.length} khối · ${soNganhHep} ngành hẹp · ${Object.keys(khung).length} khung · ${(json.length / 1024).toFixed(0)} KB`);
if (hongKhung.length) console.log(`  ⚠️ ${hongKhung.length} ngành hẹp KHÔNG có môn nào trong khung: ${hongKhung.join(', ')}`);

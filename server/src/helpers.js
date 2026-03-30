function scoreToGrade(score) {
  const s = Number(score);
  if (Number.isNaN(s) || s < 0 || s > 100) return 'F';
  if (s >= 70) return 'A';
  if (s >= 60) return 'B';
  if (s >= 50) return 'C';
  if (s >= 45) return 'D';
  return 'F';
}

function validSemester(s) {
  return s === 'First' || s === 'Second';
}

function courseMaxPairValid(maxCa, maxExam) {
  return maxCa >= 1 && maxCa <= 99 && maxExam >= 1 && maxExam <= 99 && maxCa + maxExam === 100;
}

const GRADE_POINTS = { A: 5.0, B: 4.0, C: 3.0, D: 2.0, E: 1.0, F: 0.0 };

function sessionGpa(rows) {
  let totalPoints = 0;
  let totalUnits = 0;
  for (const r of rows) {
    const unit = Number(r.unit) || 0;
    const g = String(r.grade || 'F').toUpperCase();
    const pt = GRADE_POINTS[g] ?? 0;
    totalPoints += pt * unit;
    totalUnits += unit;
  }
  if (totalUnits === 0) return 'N/A';
  return (totalPoints / totalUnits).toFixed(2);
}

module.exports = {
  scoreToGrade,
  validSemester,
  courseMaxPairValid,
  sessionGpa,
};

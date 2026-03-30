const express = require('express');
const { scoreToGrade, validSemester, courseMaxPairValid } = require('../helpers');

function requireLecturer(req, res, next) {
  if (!req.session.userId || req.session.role !== 'lecturer') {
    return res.status(403).json({ error: 'Lecturer access required.' });
  }
  next();
}

function createLecturerRouter({ db, DEFAULT_SESSION, DEFAULT_SEMESTER }) {
  const r = express.Router();
  r.use(requireLecturer);

  r.get('/courses', (req, res) => {
    const rows = db
      .prepare(
        `SELECT course_id, course_code, title, max_ca, max_exam FROM courses WHERE coordinator_id = ? ORDER BY course_code`
      )
      .all(req.session.userId);
    res.json({ courses: rows });
  });

  r.get('/courses/:courseId', (req, res) => {
    const courseId = Number(req.params.courseId);
    const course = db
      .prepare(
        `SELECT course_id, course_code, title, max_ca, max_exam FROM courses
         WHERE course_id = ? AND coordinator_id = ?`
      )
      .get(courseId, req.session.userId);
    if (!course) return res.status(404).json({ error: 'Course not found.' });
    const session = String(req.query.session || DEFAULT_SESSION);
    const semester = String(req.query.semester || DEFAULT_SEMESTER);
    if (!validSemester(semester)) {
      return res.status(400).json({ error: 'Invalid semester.' });
    }
    const students = db
      .prepare(
        `SELECT r.reg_id, u.first_name, u.last_name, smc.reg_number,
                res.ca_score, res.exam_score, res.score, res.status
         FROM registrations r
         JOIN users u ON r.student_id = u.user_id
         JOIN student_profiles sp ON u.user_id = sp.student_id
         JOIN student_credentials smc ON sp.master_record_id = smc.master_id
         LEFT JOIN results res ON r.reg_id = res.registration_id
         WHERE r.course_id = ? AND r.session = ? AND r.semester = ?
         ORDER BY smc.reg_number`
      )
      .all(courseId, session, semester);
    res.json({ course, session, semester, students });
  });

  r.post('/courses/:courseId/results', (req, res) => {
    const courseId = Number(req.params.courseId);
    const lecturerId = req.session.userId;
    const row = db
      .prepare('SELECT max_ca, max_exam FROM courses WHERE course_id = ? AND coordinator_id = ?')
      .get(courseId, lecturerId);
    if (!row) return res.status(403).json({ error: 'Not coordinator for this course.' });
    const maxCa = row.max_ca;
    const maxExam = row.max_exam;
    const { academic_session, semester, scores } = req.body || {};
    if (!academic_session || !validSemester(semester) || !scores || typeof scores !== 'object') {
      return res.status(400).json({ error: 'Invalid payload.' });
    }

    const tx = db.transaction(() => {
      for (const [regIdStr, pair] of Object.entries(scores)) {
        const regId = Number(regIdStr);
        if (!regId || !pair) continue;
        const ca = Number(pair.ca);
        const exam = Number(pair.exam);
        if (Number.isNaN(ca) || Number.isNaN(exam)) throw new Error(`Invalid scores for reg ${regId}`);
        if (ca < 0 || ca > maxCa || exam < 0 || exam > maxExam) {
          throw new Error(`CA/exam out of range for registration ${regId}`);
        }
        const total = ca + exam;
        if (total > 100) throw new Error(`Total > 100 for registration ${regId}`);
        const verify = db
          .prepare(
            `SELECT r.reg_id FROM registrations r WHERE r.reg_id = ? AND r.course_id = ? AND r.session = ? AND r.semester = ?`
          )
          .get(regId, courseId, academic_session, semester);
        if (!verify) throw new Error(`Registration ${regId} does not match period.`);
        const grade = scoreToGrade(total);
        const existing = db
          .prepare('SELECT result_id, status FROM results WHERE registration_id = ?')
          .get(regId);
        if (existing) {
          if (existing.status === 'approved') continue;
          db.prepare(
            `UPDATE results SET ca_score=?, exam_score=?, score=?, grade=?, uploaded_by=?, status='pending',
             approval_date=NULL, admin_id=NULL WHERE result_id=?`
          ).run(ca, exam, total, grade, lecturerId, existing.result_id);
        } else {
          db.prepare(
            `INSERT INTO results (registration_id, ca_score, exam_score, score, grade, uploaded_by, status)
             VALUES (?,?,?,?,?,?,'pending')`
          ).run(regId, ca, exam, total, grade, lecturerId);
        }
      }
    });
    try {
      tx();
    } catch (e) {
      return res.status(400).json({ error: e.message });
    }
    res.json({ ok: true, message: 'Results saved for approval.' });
  });

  r.post('/courses/:courseId/limits', (req, res) => {
    const courseId = Number(req.params.courseId);
    let { max_ca: maxCa, max_exam: maxExam } = req.body || {};
    maxCa = Number(maxCa);
    maxExam = Number(maxExam);
    if (!courseMaxPairValid(maxCa, maxExam)) {
      return res.status(400).json({ error: 'Max CA and max exam must be 1–99 and sum to 100.' });
    }
    const info = db
      .prepare(
        `UPDATE courses SET max_ca = ?, max_exam = ? WHERE course_id = ? AND coordinator_id = ?`
      )
      .run(maxCa, maxExam, courseId, req.session.userId);
    if (info.changes === 0) return res.status(404).json({ error: 'Course not found.' });
    res.json({ ok: true });
  });

  return r;
}

module.exports = { createLecturerRouter };

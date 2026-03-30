const express = require('express');
const { validSemester, courseMaxPairValid } = require('../helpers');

function requireAdmin(req, res, next) {
  if (!req.session.userId || req.session.role !== 'admin') {
    return res.status(403).json({ error: 'Admin access required.' });
  }
  next();
}

function createAdminRouter({ db, DEFAULT_SESSION, DEFAULT_SEMESTER }) {
  const r = express.Router();
  r.use(requireAdmin);

  r.get('/dashboard', (req, res) => {
    const pending = db.prepare("SELECT COUNT(*) AS c FROM results WHERE status = 'pending'").get();
    res.json({ pending_results: pending.c });
  });

  r.get('/users/students', (req, res) => {
    const q = (req.query.q || '').trim();
    const level = (req.query.level || '').trim();
    const dept = (req.query.department || '').trim();
    let sql = `SELECT u.user_id, u.email, u.first_name, u.last_name, u.created_at,
      smc.reg_number, smc.current_level, sp.department
      FROM users u
      JOIN student_profiles sp ON sp.student_id = u.user_id
      JOIN student_credentials smc ON sp.master_record_id = smc.master_id
      WHERE u.role = 'student'`;
    const params = [];
    if (q) {
      const like = `%${q}%`;
      sql += ` AND (u.email LIKE ? OR u.first_name LIKE ? OR u.last_name LIKE ?
        OR smc.reg_number LIKE ? OR (u.first_name || ' ' || u.last_name) LIKE ?)`;
      params.push(like, like, like, like, like);
    }
    if (level && ['100', '200', '300', '400', '500'].includes(level)) {
      sql += ' AND smc.current_level = ?';
      params.push(level);
    }
    if (dept) {
      sql += ' AND sp.department LIKE ?';
      params.push(`%${dept}%`);
    }
    sql += ' ORDER BY u.last_name, u.first_name';
    const rows = db.prepare(sql).all(...params);
    res.json({ users: rows });
  });

  r.get('/users/lecturers', (req, res) => {
    const q = (req.query.q || '').trim();
    let sql = `SELECT u.user_id, u.email, u.first_name, u.last_name, u.created_at, lc.staff_id
      FROM users u JOIN lecturer_credentials lc ON lc.user_id = u.user_id WHERE u.role = 'lecturer'`;
    const params = [];
    if (q) {
      const like = `%${q}%`;
      sql += ` AND (u.email LIKE ? OR u.first_name LIKE ? OR u.last_name LIKE ?
        OR lc.staff_id LIKE ? OR (u.first_name || ' ' || u.last_name) LIKE ?)`;
      params.push(like, like, like, like, like);
    }
    sql += ' ORDER BY u.last_name, u.first_name';
    const rows = db.prepare(sql).all(...params);
    res.json({ users: rows });
  });

  r.post('/users/:userId/delete', (req, res) => {
    const targetId = Number(req.params.userId);
    const adminId = req.session.userId;
    if (targetId === adminId) {
      return res.status(400).json({ error: 'Cannot delete your own account.' });
    }
    const u = db.prepare('SELECT user_id, role FROM users WHERE user_id = ?').get(targetId);
    if (!u) return res.status(404).json({ error: 'User not found.' });
    if (u.role === 'admin') return res.status(400).json({ error: 'Cannot delete admin.' });

    const adminRow = db
      .prepare("SELECT user_id FROM users WHERE role = 'admin' ORDER BY user_id ASC LIMIT 1")
      .get();
    if (!adminRow) return res.status(500).json({ error: 'No admin for reassignment.' });
    const systemAdminId = adminRow.user_id;

    const tx = db.transaction(() => {
      if (u.role === 'student') {
        const prof = db
          .prepare('SELECT master_record_id FROM student_profiles WHERE student_id = ?')
          .get(targetId);
        const masterId = prof ? prof.master_record_id : null;
        db.prepare(
          `DELETE FROM results WHERE registration_id IN (SELECT reg_id FROM registrations WHERE student_id = ?)`
        ).run(targetId);
        db.prepare('DELETE FROM registrations WHERE student_id = ?').run(targetId);
        db.prepare('DELETE FROM transcript_requests WHERE student_id = ?').run(targetId);
        db.prepare('DELETE FROM student_profiles WHERE student_id = ?').run(targetId);
        if (masterId != null) {
          db.prepare('UPDATE student_credentials SET is_registered = 0 WHERE master_id = ?').run(masterId);
        }
        const d = db.prepare("DELETE FROM users WHERE user_id = ? AND role = 'student'").run(targetId);
        if (d.changes === 0) throw new Error('Delete failed.');
      } else if (u.role === 'lecturer') {
        db.prepare('UPDATE courses SET coordinator_id = NULL WHERE coordinator_id = ?').run(targetId);
        db.prepare('UPDATE results SET uploaded_by = ? WHERE uploaded_by = ?').run(systemAdminId, targetId);
        db.prepare('DELETE FROM lecturer_profiles WHERE lecturer_id = ?').run(targetId);
        db.prepare(
          'UPDATE lecturer_credentials SET user_id = NULL, is_registered = 0 WHERE user_id = ?'
        ).run(targetId);
        const d = db.prepare("DELETE FROM users WHERE user_id = ? AND role = 'lecturer'").run(targetId);
        if (d.changes === 0) throw new Error('Delete failed.');
      } else throw new Error('Unsupported role.');
    });
    try {
      tx();
    } catch (e) {
      return res.status(400).json({ error: e.message });
    }
    res.json({ ok: true });
  });

  r.get('/lecturers-for-courses', (req, res) => {
    const rows = db
      .prepare(
        `SELECT u.user_id, u.first_name, u.last_name, lm.staff_id FROM users u
         JOIN lecturer_credentials lm ON u.user_id = lm.user_id WHERE u.role = 'lecturer' ORDER BY u.last_name`
      )
      .all();
    res.json({ lecturers: rows });
  });

  r.get('/courses', (req, res) => {
    const cq = (req.query.cq || '').trim();
    const coord = Number(req.query.coordinator) || 0;
    let sql = `SELECT c.course_id, c.course_code, c.title, c.unit, u.first_name, u.last_name, c.coordinator_id
      FROM courses c LEFT JOIN users u ON c.coordinator_id = u.user_id WHERE 1=1`;
    const params = [];
    if (cq) {
      const like = `%${cq}%`;
      sql += ' AND (c.course_code LIKE ? OR c.title LIKE ?)';
      params.push(like, like);
    }
    if (coord > 0) {
      sql += ' AND c.coordinator_id = ?';
      params.push(coord);
    }
    sql += ' ORDER BY c.course_code';
    const courses = db.prepare(sql).all(...params);
    res.json({ courses });
  });

  r.post('/courses', (req, res) => {
    const { course_code, title, unit, coordinator_id } = req.body || {};
    if (!course_code || !title || unit == null || !coordinator_id) {
      return res.status(400).json({ error: 'Missing fields.' });
    }
    try {
      db.prepare(
        `INSERT INTO courses (course_code, title, unit, coordinator_id, max_ca, max_exam) VALUES (?,?,?,?,30,70)`
      ).run(String(course_code).trim(), String(title).trim(), Number(unit), Number(coordinator_id));
    } catch (e) {
      if (String(e.message).includes('UNIQUE')) {
        return res.status(400).json({ error: 'Course code already exists.' });
      }
      throw e;
    }
    res.json({ ok: true });
  });

  r.post('/courses/:courseId/coordinator', (req, res) => {
    const courseId = Number(req.params.courseId);
    const { coordinator_id } = req.body || {};
    db.prepare('UPDATE courses SET coordinator_id = ? WHERE course_id = ?').run(
      Number(coordinator_id),
      courseId
    );
    res.json({ ok: true });
  });

  r.post('/master/student', (req, res) => {
    const { reg_number, full_name, current_level, entry_year } = req.body || {};
    if (!reg_number || !full_name || !current_level || entry_year == null) {
      return res.status(400).json({ error: 'Missing fields.' });
    }
    try {
      db.prepare(
        `INSERT INTO student_credentials (reg_number, full_name, current_level, entry_year, is_registered)
         VALUES (?,?,?,?,0)`
      ).run(
        String(reg_number).trim(),
        String(full_name).trim(),
        String(current_level),
        Number(entry_year)
      );
    } catch (e) {
      if (String(e.message).includes('UNIQUE')) {
        return res.status(400).json({ error: 'Matriculation number exists.' });
      }
      throw e;
    }
    res.json({ ok: true });
  });

  r.post('/master/lecturer', (req, res) => {
    const { staff_id, full_name } = req.body || {};
    if (!staff_id || !full_name) return res.status(400).json({ error: 'Missing fields.' });
    try {
      db.prepare('INSERT INTO lecturer_credentials (staff_id, full_name) VALUES (?,?)').run(
        String(staff_id).trim(),
        String(full_name).trim()
      );
    } catch (e) {
      if (String(e.message).includes('UNIQUE')) {
        return res.status(400).json({ error: 'Staff ID exists.' });
      }
      throw e;
    }
    res.json({ ok: true });
  });

  r.get('/master/students', (req, res) => {
    const mq = (req.query.mq || '').trim();
    let sql =
      'SELECT master_id, reg_number, full_name, current_level, entry_year, is_registered FROM student_credentials WHERE 1=1';
    const params = [];
    if (mq) {
      const like = `%${mq}%`;
      sql += ' AND (reg_number LIKE ? OR full_name LIKE ?)';
      params.push(like, like);
    }
    sql += ' ORDER BY reg_number LIMIT 300';
    res.json({ rows: db.prepare(sql).all(...params) });
  });

  r.get('/master/lecturers', (req, res) => {
    const mq = (req.query.mq || '').trim();
    let sql =
      'SELECT master_id, staff_id, full_name, is_registered, user_id FROM lecturer_credentials WHERE 1=1';
    const params = [];
    if (mq) {
      const like = `%${mq}%`;
      sql += ' AND (staff_id LIKE ? OR full_name LIKE ?)';
      params.push(like, like);
    }
    sql += ' ORDER BY staff_id LIMIT 300';
    res.json({ rows: db.prepare(sql).all(...params) });
  });

  r.get('/results/pending', (req, res) => {
    const q = (req.query.q || '').trim();
    const filter_session = (req.query.filter_session || '').trim();
    const filter_course = (req.query.filter_course || '').trim();
    const filter_lecturer = (req.query.filter_lecturer || '').trim();
    let sql = `SELECT res.result_id, reg.session, c.course_code, c.title AS course_title,
      u_student.first_name AS student_fname, u_student.last_name AS student_lname, smc.reg_number,
      res.ca_score, res.exam_score, res.score, res.grade,
      u_lecturer.first_name AS lecturer_fname, u_lecturer.last_name AS lecturer_lname
      FROM results res
      JOIN registrations reg ON res.registration_id = reg.reg_id
      JOIN courses c ON reg.course_id = c.course_id
      JOIN users u_student ON reg.student_id = u_student.user_id
      JOIN student_profiles sp ON u_student.user_id = sp.student_id
      JOIN student_credentials smc ON sp.master_record_id = smc.master_id
      JOIN users u_lecturer ON res.uploaded_by = u_lecturer.user_id
      WHERE res.status = 'pending'`;
    const params = [];
    if (q) {
      const like = `%${q}%`;
      sql += ` AND (c.course_code LIKE ? OR c.title LIKE ? OR u_student.first_name LIKE ?
        OR u_student.last_name LIKE ? OR smc.reg_number LIKE ?
        OR (u_lecturer.first_name || ' ' || u_lecturer.last_name) LIKE ?)`;
      params.push(like, like, like, like, like, like);
    }
    if (filter_session) {
      sql += ' AND reg.session = ?';
      params.push(filter_session);
    }
    if (filter_course) {
      sql += ' AND c.course_code LIKE ?';
      params.push(`%${filter_course}%`);
    }
    if (filter_lecturer) {
      const like = `%${filter_lecturer}%`;
      sql += ` AND (u_lecturer.first_name LIKE ? OR u_lecturer.last_name LIKE ?
        OR (u_lecturer.first_name || ' ' || u_lecturer.last_name) LIKE ?)`;
      params.push(like, like, like);
    }
    sql += ' ORDER BY c.course_code, reg.session, smc.reg_number';
    const rows = db.prepare(sql).all(...params);
    const sessions = db
      .prepare('SELECT DISTINCT session FROM registrations ORDER BY session DESC')
      .all()
      .map((x) => x.session);
    res.json({ rows, sessions });
  });

  r.post('/results/:resultId/approve', (req, res) => {
    const resultId = Number(req.params.resultId);
    const action = req.body?.action === 'reject' ? 'rejected' : 'approved';
    const info = db
      .prepare(
        `UPDATE results SET status = ?, approval_date = datetime('now'), admin_id = ? WHERE result_id = ?`
      )
      .run(action, req.session.userId, resultId);
    if (info.changes === 0) return res.status(404).json({ error: 'Result not found.' });
    res.json({ ok: true });
  });

  r.get('/transcripts/pending', (req, res) => {
    const q = (req.query.q || '').trim();
    const date_from = (req.query.date_from || '').trim();
    const date_to = (req.query.date_to || '').trim();
    let sql = `SELECT tr.request_id, tr.payment_receipt_url, tr.request_date, u.first_name, u.last_name, smc.reg_number
      FROM transcript_requests tr
      JOIN users u ON tr.student_id = u.user_id
      JOIN student_profiles sp ON u.user_id = sp.student_id
      JOIN student_credentials smc ON sp.master_record_id = smc.master_id
      WHERE tr.status = 'pending_admin_approval'`;
    const params = [];
    if (q) {
      const like = `%${q}%`;
      sql += ` AND (u.first_name LIKE ? OR u.last_name LIKE ? OR smc.reg_number LIKE ?
        OR (u.first_name || ' ' || u.last_name) LIKE ?)`;
      params.push(like, like, like, like);
    }
    if (date_from) {
      sql += ' AND date(tr.request_date) >= date(?)';
      params.push(date_from);
    }
    if (date_to) {
      sql += ' AND date(tr.request_date) <= date(?)';
      params.push(date_to);
    }
    sql += ' ORDER BY tr.request_date ASC';
    res.json({ rows: db.prepare(sql).all(...params) });
  });

  r.post('/transcripts/:requestId/approve', (req, res) => {
    const requestId = Number(req.params.requestId);
    const status = req.body?.action === 'reject' ? 'rejected' : 'approved';
    db.prepare('UPDATE transcript_requests SET status = ?, admin_id = ? WHERE request_id = ?').run(
      status,
      req.session.userId,
      requestId
    );
    res.json({ ok: true });
  });

  r.post('/registrations/search-student', (req, res) => {
    const { matric_number, academic_session, academic_semester } = req.body || {};
    if (!matric_number) return res.status(400).json({ error: 'Matric required.' });
    const session = academic_session || DEFAULT_SESSION;
    const semester = academic_semester || DEFAULT_SEMESTER;
    if (!validSemester(semester)) return res.status(400).json({ error: 'Bad semester.' });
    const like = `%${String(matric_number).trim()}%`;
    const student = db
      .prepare(
        `SELECT u.user_id, u.first_name, u.last_name, smc.reg_number, smc.current_level
         FROM users u
         JOIN student_profiles sp ON u.user_id = sp.student_id
         JOIN student_credentials smc ON sp.master_record_id = smc.master_id
         WHERE smc.reg_number LIKE ? AND u.role = 'student' LIMIT 1`
      )
      .get(like);
    if (!student) return res.json({ student: null });
    const regs = db
      .prepare(
        `SELECT r.reg_id, c.course_code, c.title FROM registrations r
         JOIN courses c ON r.course_id = c.course_id
         WHERE r.student_id = ? AND r.session = ? AND r.semester = ?`
      )
      .all(student.user_id, session, semester);
    const courses = db
      .prepare('SELECT course_id, course_code, title FROM courses ORDER BY course_code')
      .all();
    res.json({ student, session, semester, registrations: regs, courses });
  });

  r.post('/registrations/drop', (req, res) => {
    const { student_id, reg_id } = req.body || {};
    const sid = Number(student_id);
    const rid = Number(reg_id);
    const check = db
      .prepare('SELECT reg_id FROM registrations WHERE reg_id = ? AND student_id = ?')
      .get(rid, sid);
    if (!check) return res.status(400).json({ error: 'Registration not found.' });
    db.prepare('DELETE FROM registrations WHERE reg_id = ?').run(rid);
    res.json({ ok: true });
  });

  r.post('/registrations/add', (req, res) => {
    const { student_id, course_id, session, semester } = req.body || {};
    const sid = Number(student_id);
    const cid = Number(course_id);
    if (!validSemester(semester)) return res.status(400).json({ error: 'Bad semester.' });
    const dup = db
      .prepare(
        'SELECT reg_id FROM registrations WHERE student_id = ? AND course_id = ? AND session = ? AND semester = ?'
      )
      .get(sid, cid, session, semester);
    if (dup) return res.status(400).json({ error: 'Already registered for this period.' });
    db.prepare(
      'INSERT INTO registrations (student_id, course_id, session, semester) VALUES (?,?,?,?)'
    ).run(sid, cid, session, semester);
    res.json({ ok: true });
  });

  return r;
}

module.exports = { createAdminRouter };

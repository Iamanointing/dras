const express = require('express');
const path = require('path');
const { sessionGpa } = require('../helpers');

function requireStudent(req, res, next) {
  if (!req.session.userId || req.session.role !== 'student') {
    return res.status(403).json({ error: 'Student access required.' });
  }
  next();
}

function createStudentRouter({ db }) {
  const r = express.Router();
  r.use(requireStudent);

  r.get('/profile', (req, res) => {
    const row = db
      .prepare(
        `SELECT smc.reg_number, smc.current_level, smc.entry_year, sp.department
         FROM student_profiles sp
         JOIN student_credentials smc ON sp.master_record_id = smc.master_id
         WHERE sp.student_id = ?`
      )
      .get(req.session.userId);
    res.json({ profile: row || null });
  });

  r.get('/results', (req, res) => {
    const rows = db
      .prepare(
        `SELECT reg.session, reg.semester, c.course_code, c.title AS course_title, c.unit,
                res.ca_score, res.exam_score, res.score, res.grade
         FROM results res
         JOIN registrations reg ON res.registration_id = reg.reg_id
         JOIN courses c ON reg.course_id = c.course_id
         WHERE reg.student_id = ? AND res.status = 'approved'
         ORDER BY reg.session,
           CASE reg.semester WHEN 'First' THEN 1 WHEN 'Second' THEN 2 ELSE 3 END,
           c.course_code`
      )
      .all(req.session.userId);

    const bySession = {};
    for (const row of rows) {
      const s = row.session;
      const sem = row.semester;
      if (!bySession[s]) bySession[s] = {};
      if (!bySession[s][sem]) bySession[s][sem] = [];
      bySession[s][sem].push(row);
    }
    const gpas = {};
    for (const sess of Object.keys(bySession)) {
      const flat = [];
      for (const sem of Object.keys(bySession[sess])) {
        flat.push(...bySession[sess][sem]);
      }
      gpas[sess] = sessionGpa(flat);
      for (const sem of Object.keys(bySession[sess])) {
        gpas[`${sess}::${sem}`] = sessionGpa(bySession[sess][sem]);
      }
    }
    const sessions = {};
    for (const sess of Object.keys(bySession)) {
      sessions[sess] = {
        gpa: gpas[sess],
        semesters: {},
      };
      for (const sem of Object.keys(bySession[sess])) {
        sessions[sess].semesters[sem] = bySession[sess][sem];
      }
    }
    res.json({ bySession, gpas, sessions });
  });

  r.get('/transcript', (req, res) => {
    const latest = db
      .prepare(
        `SELECT request_id, status, payment_receipt_url, request_date
         FROM transcript_requests WHERE student_id = ? ORDER BY request_date DESC LIMIT 1`
      )
      .get(req.session.userId);
    const payment = db
      .prepare(
        `SELECT bank_name, account_name, account_number, fee FROM payment_details
         WHERE is_active = 1 ORDER BY detail_id DESC LIMIT 1`
      )
      .get();
    res.json({ request: latest || null, payment: payment || null });
  });

  return r;
}

function handleTranscriptUpload({ db }) {
  return (req, res) => {
    if (!req.session.userId || req.session.role !== 'student') {
      return res.status(403).json({ error: 'Student access required.' });
    }
    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded.' });
    }
    const publicPath = `uploads/receipts/${req.file.filename}`;
    const sid = req.session.userId;
    const tx = db.transaction(() => {
      const existing = db
        .prepare(
          `SELECT request_id FROM transcript_requests WHERE student_id = ? ORDER BY request_date DESC LIMIT 1`
        )
        .get(sid);
      if (existing) {
        db.prepare(
          `UPDATE transcript_requests SET payment_receipt_url = ?, status = 'pending_admin_approval',
           request_date = datetime('now') WHERE request_id = ?`
        ).run(publicPath, existing.request_id);
      } else {
        db.prepare(
          `INSERT INTO transcript_requests (student_id, payment_receipt_url, status) VALUES (?,?, 'pending_admin_approval')`
        ).run(sid, publicPath);
      }
    });
    try {
      tx();
    } catch (e) {
      const fs = require('fs');
      try {
        fs.unlinkSync(req.file.path);
      } catch (_) {}
      return res.status(500).json({ error: e.message });
    }
    res.json({ ok: true, message: 'Receipt uploaded.' });
  };
}

module.exports = { createStudentRouter, handleTranscriptUpload };

const express = require('express');
const bcrypt = require('bcryptjs');
const crypto = require('crypto');

function ensureCsrf(req) {
  if (!req.session.csrfToken) {
    req.session.csrfToken = crypto.randomBytes(24).toString('hex');
  }
  return req.session.csrfToken;
}

/** SQLite string compare is case-sensitive; emails are stored and matched in lowercase. */
function normEmail(e) {
  return String(e || '')
    .trim()
    .toLowerCase();
}

function createAuthRouter({ db, DEFAULT_SESSION, DEFAULT_SEMESTER }) {
  const r = express.Router();

  r.get('/session', (req, res) => {
    const csrfToken = ensureCsrf(req);
    if (!req.session.userId) {
      return res.json({ user: null, csrfToken });
    }
    const row = db.prepare(
      'SELECT user_id, email, role, first_name, last_name FROM users WHERE user_id = ?'
    ).get(req.session.userId);
    if (!row) {
      req.session.destroy(() => {});
      return res.json({ user: null, csrfToken });
    }
    res.json({
      user: {
        user_id: row.user_id,
        email: row.email,
        role: row.role,
        first_name: row.first_name,
        last_name: row.last_name,
      },
      csrfToken,
    });
  });

  r.post('/login', (req, res) => {
    const { email, password } = req.body || {};
    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password required.' });
    }
    const emailKey = normEmail(email);
    const row = db.prepare('SELECT * FROM users WHERE lower(email) = ?').get(emailKey);
    let hash = row && row.password_hash;
    if (hash && hash.startsWith('$2y$')) {
      hash = `$2a$${hash.slice(4)}`;
    }
    if (!row || !hash || !bcrypt.compareSync(password, hash)) {
      return res.status(401).json({ error: 'Invalid email or password.' });
    }
    req.session.userId = row.user_id;
    req.session.role = row.role;
    ensureCsrf(req);
    res.json({
      ok: true,
      user: {
        user_id: row.user_id,
        email: row.email,
        role: row.role,
        first_name: row.first_name,
        last_name: row.last_name,
      },
      csrfToken: req.session.csrfToken,
    });
  });

  r.post('/logout', (req, res) => {
    req.session.destroy(() => {
      res.json({ ok: true });
    });
  });

  /** Student/lecturer registration (credential + email) */
  r.post('/register', (req, res) => {
    const { role, credential, first_name, last_name, email, password } = req.body || {};
    if (!role || !credential || !email || !password || !first_name || !last_name) {
      return res.status(400).json({ error: 'All fields are required.' });
    }
    if (!['student', 'lecturer'].includes(role)) {
      return res.status(400).json({ error: 'Invalid role.' });
    }
    if (password.length < 8) {
      return res.status(400).json({ error: 'Password must be at least 8 characters.' });
    }
    const emailNorm = normEmail(email);
    const exists = db.prepare('SELECT 1 FROM users WHERE lower(email) = ?').get(emailNorm);
    if (exists) {
      return res.status(400).json({ error: 'This email is already registered.' });
    }

    const credCol = role === 'student' ? 'reg_number' : 'staff_id';
    const table = role === 'student' ? 'student_credentials' : 'lecturer_credentials';
    const master = db.prepare(
      `SELECT master_id, full_name, is_registered FROM ${table} WHERE ${credCol} = ?`
    ).get(String(credential).trim());

    if (!master) {
      return res.status(400).json({ error: `Credential not found (${credCol}).` });
    }
    if (master.is_registered) {
      return res.status(400).json({ error: 'This credential is already linked. Contact admin.' });
    }

    const hash = bcrypt.hashSync(password, 10);
    const tx = db.transaction(() => {
      const info = db.prepare(
        'INSERT INTO users (email, password_hash, role, first_name, last_name) VALUES (?,?,?,?,?)'
      ).run(emailNorm, hash, role, first_name.trim(), last_name.trim());
      const uid = info.lastInsertRowid;
      if (role === 'student') {
        db.prepare('INSERT INTO student_profiles (student_id, master_record_id) VALUES (?,?)').run(
          uid,
          master.master_id
        );
        db.prepare('UPDATE student_credentials SET is_registered = 1 WHERE master_id = ?').run(
          master.master_id
        );
      } else {
        db.prepare(
          'UPDATE lecturer_credentials SET user_id = ?, is_registered = 1 WHERE master_id = ?'
        ).run(uid, master.master_id);
      }
    });

    try {
      tx();
    } catch (e) {
      if (String(e.message).includes('UNIQUE')) {
        return res.status(400).json({ error: 'Duplicate email or credential.' });
      }
      throw e;
    }
    res.json({ ok: true, message: 'Registration successful. You can log in.' });
  });

  /** Direct student registration by matric */
  r.post('/register-student', (req, res) => {
    const { matric_number, email, first_name, last_name, password, confirm_password } = req.body || {};
    if (password !== confirm_password) {
      return res.status(400).json({ error: 'Passwords do not match.' });
    }
    if (!matric_number || !email || !password || !first_name || !last_name) {
      return res.status(400).json({ error: 'All fields are required.' });
    }
    if (password.length < 8) {
      return res.status(400).json({ error: 'Password must be at least 8 characters.' });
    }
    const master = db
      .prepare('SELECT master_id FROM student_credentials WHERE reg_number = ? AND is_registered = 0')
      .get(String(matric_number).trim());
    if (!master) {
      return res.status(400).json({ error: 'Invalid registration number or account already exists.' });
    }
    const emailNorm = normEmail(email);
    if (db.prepare('SELECT 1 FROM users WHERE lower(email) = ?').get(emailNorm)) {
      return res.status(400).json({ error: 'This email is already registered.' });
    }
    const hash = bcrypt.hashSync(password, 10);
    const tx = db.transaction(() => {
      const info = db.prepare(
        'INSERT INTO users (email, password_hash, role, first_name, last_name) VALUES (?,?,?,?,?)'
      ).run(emailNorm, hash, 'student', first_name.trim(), last_name.trim());
      const uid = info.lastInsertRowid;
      db.prepare('INSERT INTO student_profiles (student_id, master_record_id) VALUES (?,?)').run(
        uid,
        master.master_id
      );
      db.prepare('UPDATE student_credentials SET is_registered = 1 WHERE master_id = ?').run(
        master.master_id
      );
    });
    try {
      tx();
    } catch (e) {
      return res.status(400).json({ error: e.message || 'Registration failed.' });
    }
    res.json({ ok: true, message: 'Registration successful.' });
  });

  return r;
}

module.exports = { createAuthRouter, ensureCsrf };

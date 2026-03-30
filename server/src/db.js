const fs = require('fs');
const path = require('path');
const Database = require('better-sqlite3');

const DEFAULT_SESSION = '2024/2025';
const DEFAULT_SEMESTER = 'First';

function getDbPath() {
  const env = process.env.DRAS_SQLITE_PATH;
  if (env) return env;
  return path.join(__dirname, '..', 'data', 'dras.sqlite');
}

function initDb() {
  const dbPath = getDbPath();
  fs.mkdirSync(path.dirname(dbPath), { recursive: true });
  const db = new Database(dbPath);
  db.pragma('journal_mode = WAL');
  db.pragma('foreign_keys = ON');

  const hasUsers = db.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name='users'").get();
  if (!hasUsers) {
    const initSql = fs.readFileSync(path.join(__dirname, '..', 'sql', 'init.sql'), 'utf8');
    try {
      db.exec(initSql);
    } catch (e) {
      console.error('SQL init error:', e.message);
      throw e;
    }
  }

  try {
    db.prepare('UPDATE users SET email = lower(trim(email)) WHERE email IS NOT NULL').run();
  } catch (_) {
    /* ignore */
  }

  return { db, DEFAULT_SESSION, DEFAULT_SEMESTER };
}

module.exports = { initDb, getDbPath };

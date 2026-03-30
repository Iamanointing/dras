const path = require('path');
const fs = require('fs');
const express = require('express');
const session = require('express-session');
const cookieParser = require('cookie-parser');
const multer = require('multer');
const { initDb } = require('./db');
const { createAuthRouter } = require('./routes/auth');
const { createStudentRouter, handleTranscriptUpload } = require('./routes/student');
const { createLecturerRouter } = require('./routes/lecturer');
const { createAdminRouter } = require('./routes/admin');

const isProd = process.env.NODE_ENV === 'production';
if (isProd) {
  const sec = process.env.SESSION_SECRET;
  if (!sec || sec === 'dev-change-me-in-production') {
    console.error('FATAL: Set SESSION_SECRET in production (e.g. Render env vars).');
    process.exit(1);
  }
}

const { db, DEFAULT_SESSION, DEFAULT_SEMESTER } = initDb();
const app = express();
app.set('etag', false);
const PORT = Number(process.env.PORT) || 3000;
const SESSION_SECRET = process.env.SESSION_SECRET || 'dev-change-me-in-production';

const uploadsRoot = process.env.DRAS_UPLOADS_DIR
  ? path.resolve(process.env.DRAS_UPLOADS_DIR)
  : path.join(__dirname, '..', 'uploads');

app.set('trust proxy', 1);
app.get('/healthz', (_req, res) => {
  res.status(200).type('text/plain').send('ok');
});
app.use(cookieParser());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.use(
  session({
    secret: SESSION_SECRET,
    proxy: true,
    resave: false,
    saveUninitialized: false,
    cookie: {
      httpOnly: true,
      sameSite: 'lax',
      secure: process.env.NODE_ENV === 'production',
      maxAge: 7 * 24 * 60 * 60 * 1000,
    },
  })
);

function csrfApi(req, res, next) {
  const m = req.method;
  if (!['POST', 'PUT', 'PATCH', 'DELETE'].includes(m)) {
    return next();
  }
  const fullPath = ((req.baseUrl || '') + (req.path || '')).split('?')[0];
  const orig = (req.originalUrl || '').split('?')[0];
  const skip =
    ['/api/auth/login', '/api/auth/register', '/api/auth/register-student'].includes(fullPath) ||
    ['/api/auth/login', '/api/auth/register', '/api/auth/register-student'].includes(orig);
  if (skip) return next();
  const token = req.get('x-csrf-token') || (req.body && req.body._csrf);
  if (!token || !req.session.csrfToken || token !== req.session.csrfToken) {
    return res.status(403).json({ error: 'Invalid or missing CSRF token.' });
  }
  next();
}

app.use('/api', csrfApi);

app.use('/api/auth', createAuthRouter({ db, DEFAULT_SESSION, DEFAULT_SEMESTER }));
app.use('/api/student', createStudentRouter({ db }));
app.use('/api/lecturer', createLecturerRouter({ db, DEFAULT_SESSION, DEFAULT_SEMESTER }));
app.use('/api/admin', createAdminRouter({ db, DEFAULT_SESSION, DEFAULT_SEMESTER }));

const uploadDir = path.join(uploadsRoot, 'receipts');
fs.mkdirSync(uploadDir, { recursive: true });
const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, uploadDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname) || '.bin';
    const base = `${req.session.userId}-${Date.now()}${ext}`;
    cb(null, base.replace(/[^a-zA-Z0-9._-]/g, '_'));
  },
});
const upload = multer({
  storage,
  limits: { fileSize: 8 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    const ok = /\.(pdf|jpg|jpeg|png)$/i.test(file.originalname);
    cb(ok ? null : new Error('Only PDF or image files allowed.'), ok);
  },
});

app.post(
  '/api/student/transcript/upload',
  (req, res, next) => {
    if (!req.session.userId || req.session.role !== 'student') {
      return res.status(403).json({ error: 'Student access required.' });
    }
    next();
  },
  (req, res, next) => {
    upload.single('receipt')(req, res, (err) => {
      if (err) return res.status(400).json({ error: err.message || 'Upload failed.' });
      next();
    });
  },
  handleTranscriptUpload({ db })
);

app.use('/uploads', express.static(uploadsRoot));
app.use(express.static(path.join(__dirname, '..', 'public')));

app.listen(PORT, () => {
  console.log(`DRAS listening on http://localhost:${PORT}`);
});

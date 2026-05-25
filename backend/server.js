const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');

const buildingsRouter = require('./src/routes/buildings');
const fingerprintsRouter = require('./src/routes/fingerprints');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(helmet());
app.use(cors());
app.use(morgan('dev'));
app.use(express.json({ limit: '10mb' }));

// ── Routes ─────────────────────────────────────────────────────────────────
app.use('/api/buildings', buildingsRouter);
app.use('/api/fingerprints', fingerprintsRouter);

app.get('/api/health', (_, res) => res.json({ status: 'ok', ts: new Date() }));

// ── Error handler ──────────────────────────────────────────────────────────
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: err.message });
});

app.listen(PORT, () =>
  console.log(`NavegaVis backend running on http://localhost:${PORT}`)
);

module.exports = app;

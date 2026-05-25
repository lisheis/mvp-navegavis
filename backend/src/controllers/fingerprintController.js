const { v4: uuidv4 } = require('uuid');
const db = require('../db/database');

exports.listFingerprints = (req, res) => {
  const { buildingId, nodeId, floor } = req.query;
  let query = 'SELECT * FROM wifi_fingerprints WHERE 1=1';
  const params = [];

  if (buildingId) { query += ' AND building_id = ?'; params.push(buildingId); }
  if (nodeId)    { query += ' AND node_id = ?';     params.push(nodeId); }
  if (floor !== undefined) { query += ' AND floor = ?'; params.push(parseInt(floor)); }

  const rows = db.prepare(query).all(...params);
  res.json(rows.map(r => ({
    id: r.id,
    nodeId: r.node_id,
    buildingId: r.building_id,
    floor: r.floor,
    readings: JSON.parse(r.readings),
    collectedAt: r.collected_at,
  })));
};

exports.createFingerprint = (req, res) => {
  const { nodeId, buildingId, floor, readings, collectedAt } = req.body;
  if (!nodeId || !buildingId || !readings) {
    return res.status(400).json({ error: 'nodeId, buildingId, readings required' });
  }

  const id = uuidv4();
  db.prepare(
    'INSERT INTO wifi_fingerprints (id, building_id, node_id, floor, readings, collected_at) VALUES (?, ?, ?, ?, ?, ?)'
  ).run(id, buildingId, nodeId, floor || 0, JSON.stringify(readings), collectedAt || new Date().toISOString());

  res.status(201).json({ id });
};

exports.deleteFingerprint = (req, res) => {
  db.prepare('DELETE FROM wifi_fingerprints WHERE id = ?').run(req.params.id);
  res.status(204).end();
};

exports.clearBuildingFingerprints = (req, res) => {
  db.prepare('DELETE FROM wifi_fingerprints WHERE building_id = ?').run(req.params.buildingId);
  res.status(204).end();
};

/// Simple server-side kNN for verification/debugging (the real inference runs on the device).
exports.estimatePosition = (req, res) => {
  const { buildingId, floor, scan } = req.body; // scan: [{bssid, rssi}]
  if (!buildingId || !scan) return res.status(400).json({ error: 'buildingId and scan required' });

  const fps = db.prepare('SELECT * FROM wifi_fingerprints WHERE building_id = ? AND floor = ?')
    .all(buildingId, floor || 0);

  if (fps.length === 0) return res.json({ nodeId: null, confidence: 0 });

  const liveMap = {};
  for (const s of scan) liveMap[s.bssid] = s.rssi;

  const scored = fps.map(fp => {
    const stored = {};
    for (const r of JSON.parse(fp.readings)) stored[r.bssid] = r.rssi;
    const allBssids = new Set([...Object.keys(liveMap), ...Object.keys(stored)]);
    let sum = 0;
    for (const b of allBssids) {
      const diff = (liveMap[b] ?? -100) - (stored[b] ?? -100);
      sum += diff * diff;
    }
    return { nodeId: fp.node_id, dist: Math.sqrt(sum) };
  });

  scored.sort((a, b) => a.dist - b.dist);
  const best = scored[0];
  const confidence = Math.max(0, 1 - best.dist / 200);

  res.json({ nodeId: best.nodeId, confidence, dist: best.dist });
};

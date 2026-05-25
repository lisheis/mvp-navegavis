const { v4: uuidv4 } = require('uuid');
const db = require('../db/database');

function buildBuilding(id) {
  const building = db.prepare('SELECT * FROM buildings WHERE id = ?').get(id);
  if (!building) return null;

  const floorPlans = db.prepare('SELECT * FROM floor_plans WHERE building_id = ?').all(id);
  const nodes = db.prepare('SELECT * FROM nav_nodes WHERE building_id = ?').all(id);
  const edges = db.prepare('SELECT * FROM nav_edges WHERE building_id = ?').all(id);
  const fps = db.prepare('SELECT * FROM wifi_fingerprints WHERE building_id = ?').all(id);

  return {
    id: building.id,
    name: building.name,
    address: building.address,
    lastSynced: building.updated_at,
    floorPlans: floorPlans.map(f => ({
      floor: f.floor,
      imageUrl: f.image_url,
      widthMeters: f.width_meters,
      heightMeters: f.height_meters,
    })),
    nodes: nodes.map(n => ({
      id: n.id,
      label: n.label,
      x: n.x,
      y: n.y,
      floor: n.floor,
      nodeType: n.node_type,
      buildingId: n.building_id,
      metadata: n.metadata ? JSON.parse(n.metadata) : {},
    })),
    edges: edges.map(e => ({
      id: e.id,
      fromNodeId: e.from_node_id,
      toNodeId: e.to_node_id,
      weight: e.weight,
      bidirectional: !!e.bidirectional,
      edgeType: e.edge_type,
      accessible: !!e.accessible,
    })),
    fingerprints: fps.map(f => ({
      id: f.id,
      nodeId: f.node_id,
      buildingId: f.building_id,
      floor: f.floor,
      readings: JSON.parse(f.readings),
      collectedAt: f.collected_at,
    })),
  };
}

exports.listBuildings = (req, res) => {
  const rows = db.prepare('SELECT id FROM buildings ORDER BY created_at DESC').all();
  const buildings = rows.map(r => buildBuilding(r.id)).filter(Boolean);
  res.json(buildings);
};

exports.getBuilding = (req, res) => {
  const b = buildBuilding(req.params.id);
  if (!b) return res.status(404).json({ error: 'Building not found' });
  res.json(b);
};

exports.createBuilding = (req, res) => {
  const { name, address = '', floorPlans = [] } = req.body;
  if (!name) return res.status(400).json({ error: 'name required' });

  const id = uuidv4();
  db.prepare('INSERT INTO buildings (id, name, address) VALUES (?, ?, ?)').run(id, name, address);

  const defaultPlans = floorPlans.length > 0 ? floorPlans : [{ floor: 0, widthMeters: 50, heightMeters: 30 }];
  for (const fp of defaultPlans) {
    db.prepare(
      'INSERT INTO floor_plans (id, building_id, floor, image_url, width_meters, height_meters) VALUES (?, ?, ?, ?, ?, ?)'
    ).run(uuidv4(), id, fp.floor, fp.imageUrl || null, fp.widthMeters || 50, fp.heightMeters || 30);
  }

  res.status(201).json(buildBuilding(id));
};

exports.updateBuilding = (req, res) => {
  const { name, address, nodes, edges } = req.body;
  const id = req.params.id;

  if (name || address !== undefined) {
    db.prepare('UPDATE buildings SET name = COALESCE(?, name), address = COALESCE(?, address), updated_at = datetime(\'now\') WHERE id = ?')
      .run(name || null, address !== undefined ? address : null, id);
  }

  if (nodes) {
    db.prepare('DELETE FROM nav_nodes WHERE building_id = ?').run(id);
    const ins = db.prepare(
      'INSERT INTO nav_nodes (id, building_id, label, x, y, floor, node_type, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
    );
    for (const n of nodes) {
      ins.run(n.id || uuidv4(), id, n.label, n.x, n.y, n.floor, n.nodeType || 'corridor', JSON.stringify(n.metadata || {}));
    }
  }

  if (edges) {
    db.prepare('DELETE FROM nav_edges WHERE building_id = ?').run(id);
    const ins = db.prepare(
      'INSERT INTO nav_edges (id, building_id, from_node_id, to_node_id, weight, bidirectional, edge_type, accessible) VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
    );
    for (const e of edges) {
      ins.run(e.id || uuidv4(), id, e.fromNodeId, e.toNodeId, e.weight, e.bidirectional ? 1 : 0, e.edgeType || 'walk', e.accessible !== false ? 1 : 0);
    }
  }

  res.json(buildBuilding(id));
};

exports.deleteBuilding = (req, res) => {
  db.prepare('DELETE FROM buildings WHERE id = ?').run(req.params.id);
  res.status(204).end();
};

exports.updateGraph = (req, res) => {
  const { nodes = [], edges = [] } = req.body;
  const id = req.params.id;

  const txn = db.transaction(() => {
    db.prepare('DELETE FROM nav_nodes WHERE building_id = ?').run(id);
    db.prepare('DELETE FROM nav_edges WHERE building_id = ?').run(id);

    const insNode = db.prepare(
      'INSERT INTO nav_nodes (id, building_id, label, x, y, floor, node_type, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
    );
    for (const n of nodes) {
      insNode.run(n.id || uuidv4(), id, n.label, n.x, n.y, n.floor, n.nodeType || 'corridor', JSON.stringify(n.metadata || {}));
    }

    const insEdge = db.prepare(
      'INSERT INTO nav_edges (id, building_id, from_node_id, to_node_id, weight, bidirectional, edge_type, accessible) VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
    );
    for (const e of edges) {
      insEdge.run(e.id || uuidv4(), id, e.fromNodeId, e.toNodeId, e.weight, e.bidirectional ? 1 : 0, e.edgeType || 'walk', e.accessible !== false ? 1 : 0);
    }
  });
  txn();

  db.prepare("UPDATE buildings SET updated_at = datetime('now') WHERE id = ?").run(id);
  res.json({ ok: true });
};

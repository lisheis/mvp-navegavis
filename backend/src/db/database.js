const Database = require('better-sqlite3');
const path = require('path');

const DB_PATH = path.join(__dirname, '..', '..', 'data', 'navegavis.db');

// Ensure data directory exists
const fs = require('fs');
fs.mkdirSync(path.dirname(DB_PATH), { recursive: true });

const db = new Database(DB_PATH);

// Enable WAL mode for better concurrent read performance
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

db.exec(`
  CREATE TABLE IF NOT EXISTS buildings (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    address TEXT DEFAULT '',
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
  );

  CREATE TABLE IF NOT EXISTS floor_plans (
    id TEXT PRIMARY KEY,
    building_id TEXT NOT NULL REFERENCES buildings(id) ON DELETE CASCADE,
    floor INTEGER NOT NULL,
    image_url TEXT,
    width_meters REAL NOT NULL DEFAULT 50,
    height_meters REAL NOT NULL DEFAULT 30
  );

  CREATE TABLE IF NOT EXISTS nav_nodes (
    id TEXT PRIMARY KEY,
    building_id TEXT NOT NULL REFERENCES buildings(id) ON DELETE CASCADE,
    label TEXT NOT NULL,
    x REAL NOT NULL,
    y REAL NOT NULL,
    floor INTEGER NOT NULL DEFAULT 0,
    node_type TEXT NOT NULL DEFAULT 'corridor',
    metadata TEXT DEFAULT '{}'
  );

  CREATE TABLE IF NOT EXISTS nav_edges (
    id TEXT PRIMARY KEY,
    building_id TEXT NOT NULL REFERENCES buildings(id) ON DELETE CASCADE,
    from_node_id TEXT NOT NULL REFERENCES nav_nodes(id) ON DELETE CASCADE,
    to_node_id TEXT NOT NULL REFERENCES nav_nodes(id) ON DELETE CASCADE,
    weight REAL NOT NULL,
    bidirectional INTEGER NOT NULL DEFAULT 1,
    edge_type TEXT NOT NULL DEFAULT 'walk',
    accessible INTEGER NOT NULL DEFAULT 1
  );

  CREATE TABLE IF NOT EXISTS wifi_fingerprints (
    id TEXT PRIMARY KEY,
    building_id TEXT NOT NULL REFERENCES buildings(id) ON DELETE CASCADE,
    node_id TEXT NOT NULL REFERENCES nav_nodes(id) ON DELETE CASCADE,
    floor INTEGER NOT NULL,
    readings TEXT NOT NULL,
    collected_at TEXT NOT NULL
  );
`);

module.exports = db;

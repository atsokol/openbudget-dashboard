// DuckDB WASM client for browser-side querying
import * as duckdb from "@duckdb/duckdb-wasm";

let dbInstance = null;
let connInstance = null;

export async function getDuckDB() {
  if (dbInstance) return { db: dbInstance, conn: connInstance };

  // Select appropriate bundle for the browser
  const JSDELIVR_BUNDLES = duckdb.getJsDelivrBundles();
  const bundle = await duckdb.selectBundle(JSDELIVR_BUNDLES);
  
  // Instantiate DuckDB
  const worker = new Worker(bundle.mainWorker);
  const logger = new duckdb.ConsoleLogger();
  dbInstance = new duckdb.AsyncDuckDB(logger, worker);
  await dbInstance.instantiate(bundle.mainModule, bundle.pthreadWorker);
  
  // Create connection
  connInstance = await dbInstance.connect();
  
  // Register the database file
  const dbFile = await FileAttachment("data/budget.duckdb").arrayBuffer();
  await dbInstance.registerFileBuffer("budget.duckdb", new Uint8Array(dbFile));
  
  return { db: dbInstance, conn: connInstance };
}

export async function query(sql) {
  const { conn } = await getDuckDB();
  const result = await conn.query(sql);
  return result.toArray();
}

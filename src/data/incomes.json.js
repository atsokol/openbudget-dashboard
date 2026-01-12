#!/usr/bin/env node
// This file is now a stub - data is loaded via DuckDB WASM in the browser
// Keeping for build compatibility
process.stdout.write(JSON.stringify([]));
  });
});

// Convert BigInt to number for JSON serialization
const jsonResult = result.map(row => {
  const newRow = {};
  for (const [key, value] of Object.entries(row)) {
    newRow[key] = typeof value === 'bigint' ? Number(value) : value;
  }
  return newRow;
});

process.stdout.write(JSON.stringify(jsonResult));


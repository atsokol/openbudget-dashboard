#!/usr/bin/env node

// Data loader for EUR/UAH exchange rates from National Bank of Ukraine API
// Downloads daily exchange rates and outputs as JSON

const response = await fetch(
  "https://bank.gov.ua/NBU_Exchange/exchange_site?start=20210101&end=20991231&valcode=eur&sort=exchangedate&order=desc&json"
);

if (!response.ok) {
  throw new Error(`Failed to fetch FX rates: ${response.status} ${response.statusText}`);
}

const data = await response.json();

// Transform and clean the data
const fxRates = data.map(d => ({
  date: d.exchangedate.split('.').reverse().join('-'), // Convert DD.MM.YYYY to YYYY-MM-DD
  rate: parseFloat(d.rate)
})).sort((a, b) => a.date.localeCompare(b.date)); // Sort by date ascending

process.stdout.write(JSON.stringify(fxRates));

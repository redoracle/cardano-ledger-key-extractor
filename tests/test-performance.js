#!/usr/bin/env node
/**
 * Performance Test Suite for Cardano Ledger Key Extractor
 *
 * Tests critical path performance and reports timing metrics.
 * This script benchmarks the core operations to detect performance regressions.
 */

const {
  generateLedgerMasterKey,
  validateMnemonic,
  toHexString,
  // Note: Following imports are available for potential future use
  toByteArray: _toByteArray,
  hashRepeatedly: _hashRepeatedly,
  tweakBits: _tweakBits,
} = require("../index");

const bip39 = require("bip39");

// Test configuration
const WARMUP_ROUNDS = 5;
const BENCHMARK_ROUNDS = 50;
const BATCH_SIZE = 10;

// Known test mnemonic for consistent benchmarking
const TEST_MNEMONIC =
  "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about";

/**
 * High-precision timer utility
 */
function getTimeMs() {
  const [seconds, nanoseconds] = process.hrtime();
  return seconds * 1000 + nanoseconds / 1000000;
}

/**
 * Calculate statistics from timing array
 */
function calculateStats(times) {
  const sorted = [...times].sort((a, b) => a - b);
  const mean = times.reduce((sum, time) => sum + time, 0) / times.length;
  const median = sorted[Math.floor(sorted.length / 2)];
  const p95 = sorted[Math.floor(sorted.length * 0.95)];
  const p99 = sorted[Math.floor(sorted.length * 0.99)];
  const min = Math.min(...times);
  const max = Math.max(...times);

  return { mean, median, p95, p99, min, max };
}

/**
 * Format timing statistics for display
 */
function formatStats(stats, unit = "ms") {
  return {
    mean: `${stats.mean.toFixed(2)}${unit}`,
    median: `${stats.median.toFixed(2)}${unit}`,
    p95: `${stats.p95.toFixed(2)}${unit}`,
    p99: `${stats.p99.toFixed(2)}${unit}`,
    min: `${stats.min.toFixed(2)}${unit}`,
    max: `${stats.max.toFixed(2)}${unit}`,
  };
}

/**
 * Benchmark mnemonic validation
 */
function benchmarkMnemonicValidation() {
  console.log("🧪 Benchmarking mnemonic validation...");

  const times = [];
  const testMnemonics = [
    TEST_MNEMONIC,
    bip39.generateMnemonic(160), // 15 words
    bip39.generateMnemonic(192), // 18 words
    bip39.generateMnemonic(224), // 21 words
    bip39.generateMnemonic(256), // 24 words
  ];

  // Warmup
  for (let i = 0; i < WARMUP_ROUNDS; i++) {
    validateMnemonic(TEST_MNEMONIC);
  }

  // Benchmark
  for (let i = 0; i < BENCHMARK_ROUNDS; i++) {
    const mnemonic = testMnemonics[i % testMnemonics.length];
    const start = getTimeMs();
    validateMnemonic(mnemonic);
    const end = getTimeMs();
    times.push(end - start);
  }

  const stats = calculateStats(times);
  const formatted = formatStats(stats);

  console.log(
    `   Average: ${formatted.mean} | Median: ${formatted.median} | P95: ${formatted.p95}`,
  );
  console.log(`   Range: ${formatted.min} - ${formatted.max}`);

  // Performance assertions
  if (stats.p95 > 50) {
    console.warn(
      `   ⚠️  P95 latency (${formatted.p95}) exceeds 50ms threshold`,
    );
  }

  return stats;
}

/**
 * Benchmark master key generation
 */
function benchmarkMasterKeyGeneration() {
  console.log("🔑 Benchmarking master key generation...");

  const times = [];
  const entropy = bip39.mnemonicToEntropy(TEST_MNEMONIC);
  const passphrases = [
    "",
    "test",
    "longer passphrase for testing",
    "🔒secure🔒",
  ];

  // Warmup
  for (let i = 0; i < WARMUP_ROUNDS; i++) {
    generateLedgerMasterKey(entropy, "");
  }

  // Benchmark
  for (let i = 0; i < BENCHMARK_ROUNDS; i++) {
    const passphrase = passphrases[i % passphrases.length];
    const start = getTimeMs();
    generateLedgerMasterKey(entropy, passphrase);
    const end = getTimeMs();
    times.push(end - start);
  }

  const stats = calculateStats(times);
  const formatted = formatStats(stats);

  console.log(
    `   Average: ${formatted.mean} | Median: ${formatted.median} | P95: ${formatted.p95}`,
  );
  console.log(`   Range: ${formatted.min} - ${formatted.max}`);

  // Performance assertions
  if (stats.p95 > 1000) {
    console.warn(
      `   ⚠️  P95 latency (${formatted.p95}) exceeds 1000ms threshold`,
    );
  }

  return stats;
}

/**
 * Benchmark hex conversion operations
 */
function benchmarkHexConversion() {
  console.log("🔄 Benchmarking hex conversion...");

  const times = [];
  const testData = crypto.randomBytes(96); // 96 bytes like master key

  // Warmup
  for (let i = 0; i < WARMUP_ROUNDS * 10; i++) {
    toHexString(testData);
  }

  // Benchmark
  for (let i = 0; i < BENCHMARK_ROUNDS * 10; i++) {
    const start = getTimeMs();
    toHexString(testData);
    const end = getTimeMs();
    times.push(end - start);
  }

  const stats = calculateStats(times);
  const _formatted = formatStats(stats, "µs");

  // Convert to microseconds for better readability
  Object.keys(stats).forEach((key) => {
    stats[key] *= 1000;
  });

  console.log(
    `   Average: ${stats.mean.toFixed(1)}µs | Median: ${stats.median.toFixed(1)}µs | P95: ${stats.p95.toFixed(1)}µs`,
  );

  return stats;
}

/**
 * Benchmark batch operations (real-world scenario)
 */
function benchmarkBatchOperations() {
  console.log("📦 Benchmarking batch operations...");

  const times = [];

  // Warmup
  for (let i = 0; i < WARMUP_ROUNDS; i++) {
    const entropy = bip39.mnemonicToEntropy(TEST_MNEMONIC);
    generateLedgerMasterKey(entropy, "");
  }

  // Benchmark batch processing
  for (let batch = 0; batch < BENCHMARK_ROUNDS / BATCH_SIZE; batch++) {
    const start = getTimeMs();

    for (let i = 0; i < BATCH_SIZE; i++) {
      const entropy = bip39.mnemonicToEntropy(TEST_MNEMONIC);
      const masterKey = generateLedgerMasterKey(entropy, String(i));
      toHexString(masterKey);
    }

    const end = getTimeMs();
    times.push((end - start) / BATCH_SIZE); // Per-operation time
  }

  const stats = calculateStats(times);
  const formatted = formatStats(stats);

  console.log(
    `   Per-operation: ${formatted.mean} | Median: ${formatted.median} | P95: ${formatted.p95}`,
  );
  console.log(`   Throughput: ${(1000 / stats.mean).toFixed(1)} ops/sec`);

  return stats;
}

/**
 * Memory usage tracking
 */
function measureMemoryUsage() {
  console.log("💾 Measuring memory usage...");

  const initialMemory = process.memoryUsage();

  // Perform intensive operations
  const entropy = bip39.mnemonicToEntropy(TEST_MNEMONIC);
  const masterKeys = [];

  for (let i = 0; i < 100; i++) {
    const masterKey = generateLedgerMasterKey(entropy, String(i));
    masterKeys.push(toHexString(masterKey));
  }

  const finalMemory = process.memoryUsage();

  const memoryDelta = {
    rss: finalMemory.rss - initialMemory.rss,
    heapTotal: finalMemory.heapTotal - initialMemory.heapTotal,
    heapUsed: finalMemory.heapUsed - initialMemory.heapUsed,
    external: finalMemory.external - initialMemory.external,
  };

  console.log(`   RSS: ${(memoryDelta.rss / 1024 / 1024).toFixed(2)}MB delta`);
  console.log(
    `   Heap Used: ${(memoryDelta.heapUsed / 1024 / 1024).toFixed(2)}MB delta`,
  );

  // Check for memory leaks
  if (memoryDelta.heapUsed > 50 * 1024 * 1024) {
    // 50MB
    console.warn(
      `   ⚠️  High memory usage detected: ${(memoryDelta.heapUsed / 1024 / 1024).toFixed(2)}MB`,
    );
  }

  return memoryDelta;
}

/**
 * Main performance test runner
 */
async function runPerformanceTests() {
  console.log("🚀 Cardano Ledger Key Extractor - Performance Tests");
  console.log("=".repeat(60));
  console.log(
    `Node.js: ${process.version} | Platform: ${process.platform} ${process.arch}`,
  );
  console.log(
    `CPU Cores: ${require("os").cpus().length} | Memory: ${(require("os").totalmem() / 1024 / 1024 / 1024).toFixed(1)}GB`,
  );
  console.log("");

  const results = {};

  try {
    // Core operation benchmarks
    results.mnemonicValidation = benchmarkMnemonicValidation();
    console.log("");

    results.masterKeyGeneration = benchmarkMasterKeyGeneration();
    console.log("");

    results.hexConversion = benchmarkHexConversion();
    console.log("");

    results.batchOperations = benchmarkBatchOperations();
    console.log("");

    // Memory usage measurement
    results.memoryUsage = measureMemoryUsage();
    console.log("");

    // Summary
    console.log("📊 Performance Summary");
    console.log("=".repeat(30));
    console.log(
      `✅ Mnemonic validation: ${formatStats(results.mnemonicValidation).p95} (P95)`,
    );
    console.log(
      `✅ Master key generation: ${formatStats(results.masterKeyGeneration).p95} (P95)`,
    );
    console.log(
      `✅ Batch throughput: ${(1000 / results.batchOperations.mean).toFixed(1)} ops/sec`,
    );

    // Performance warnings
    const warnings = [];
    if (results.mnemonicValidation.p95 > 50)
      warnings.push("Slow mnemonic validation");
    if (results.masterKeyGeneration.p95 > 1000)
      warnings.push("Slow master key generation");
    if (results.memoryUsage.heapUsed > 50 * 1024 * 1024)
      warnings.push("High memory usage");

    if (warnings.length > 0) {
      console.log("");
      console.log("⚠️  Performance Warnings:");
      warnings.forEach((warning) => console.log(`   - ${warning}`));
    }

    console.log("");
    console.log("🎯 All performance tests completed successfully!");
  } catch (error) {
    console.error("❌ Performance test failed:", error.message);
    process.exit(1);
  }
}

// Add crypto import that was missing
const crypto = require("crypto");

// Run tests if called directly
if (require.main === module) {
  runPerformanceTests();
}

module.exports = {
  runPerformanceTests,
  benchmarkMnemonicValidation,
  benchmarkMasterKeyGeneration,
  benchmarkHexConversion,
  benchmarkBatchOperations,
  measureMemoryUsage,
};

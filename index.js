#!/usr/bin/env node

const crypto = require("crypto");
const bip39 = require("bip39");

/**
 * Converts a hex string to a Uint8Array
 * @param {string} hexString - Hex string to convert
 * @returns {Uint8Array} Byte array
 */
function toByteArray(hexString) {
  const result = new Uint8Array(hexString.length / 2);
  for (let i = 0; i < hexString.length; i += 2) {
    result[i / 2] = parseInt(hexString.substring(i, i + 2), 16);
  }
  return result;
}

/**
 * Converts a byte array to hex string
 * @param {Uint8Array} bytes - Byte array to convert
 * @returns {string} Hex string
 */
const toHexString = (bytes) =>
  bytes.reduce((str, byte) => str + byte.toString(16).padStart(2, "0"), "");

/**
 * Validates a BIP39 mnemonic phrase
 * @param {string} mnemonic - The mnemonic phrase to validate
 * @throws {Error} If mnemonic is invalid
 * @returns {string} Trimmed and validated mnemonic
 */
function validateMnemonic(mnemonic) {
  if (!mnemonic || typeof mnemonic !== "string") {
    throw new Error("Mnemonic must be a non-empty string");
  }

  const trimmed = mnemonic.trim();
  const wordCount = trimmed.split(/\s+/).length;
  const validCounts = [12, 15, 18, 21, 24];

  if (!validCounts.includes(wordCount)) {
    throw new Error(
      `Invalid word count: ${wordCount}. Must be 12, 15, 18, 21, or 24 words.`,
    );
  }

  if (!bip39.validateMnemonic(trimmed)) {
    throw new Error("Invalid mnemonic checksum or word list");
  }

  return trimmed;
}

/**
 * Generates a Ledger-compatible master key from BIP39 entropy
 * Originally from Adrestia https://IntersectMBO.github.io/adrestia/docs/key-concepts/hierarchical-deterministic-wallets/
 * Modified to fix issues with the original implementation
 *
 * @param {string} seed - BIP39 entropy (hex string)
 * @param {string} password - Optional passphrase (empty string if none)
 * @returns {Uint8Array} 96-byte master key (64-byte key + 32-byte chain code)
 */
function generateLedgerMasterKey(seed, password) {
  // Convert entropy to mnemonic and derive master seed using PBKDF2
  const masterSeed = crypto.pbkdf2Sync(
    bip39.entropyToMnemonic(seed),
    "mnemonic" + password,
    2048,
    64,
    "sha512",
  );

  // Generate chain code
  // Note: Adrestia's pseudo code had "1" + seed, which was incorrect
  const message = new Uint8Array([1, ...masterSeed]);
  const cc = crypto
    .createHmac("sha256", "ed25519 seed")
    .update(message)
    .digest();

  // Hash repeatedly until we get a valid key
  const i = hashRepeatedly(masterSeed);
  const tweaked = tweakBits(i);

  // Combine key and chain code (96 bytes total)
  const masterKey = new Uint8Array([...tweaked, ...cc]);

  return masterKey;
}

/**
 * Repeatedly hash until we get a valid ed25519 key
 * @param {Buffer} message - Message to hash
 * @returns {Buffer} Valid hashed key
 */
function hashRepeatedly(message) {
  const i = crypto
    .createHmac("sha512", "ed25519 seed")
    .update(message)
    .digest();

  // Check if 3rd highest bit of last byte is set
  if (i[31] & 0b0010_0000) {
    return hashRepeatedly(i);
  }
  return i;
}

/**
 * Apply ed25519 bit tweaks to make a valid signing key
 * @param {Buffer} data - Key data to tweak
 * @returns {Buffer} Tweaked key data
 */
function tweakBits(data) {
  // Clear the lowest 3 bits (make divisible by 8)
  data[0] &= 0b1111_1000;
  // Clear the highest bit
  data[31] &= 0b0111_1111;
  // Set the highest 2nd bit
  data[31] |= 0b0100_0000;

  return data;
}

/**
 * Display usage information
 */
function showHelp() {
  console.log(`
Cardano Ledger Master Key Generator
====================================

Usage:
  node index.js [options]

Options:
  --test              Use canonical test mnemonic (abandon... about)
  --mnemonic "words"  Provide mnemonic as argument (NOT RECOMMENDED - use stdin)
  --passphrase "pass" Optional BIP39 passphrase (default: empty)
  --derive-only       Output only the master key (no formatting, for scripting)
  --no-interactive    Disable interactive mode (require stdin or mnemonic arg)
  --help              Show this help message

Environment Variables:
  MNEMONIC            Read mnemonic from environment (NOT RECOMMENDED)
  PASSPHRASE          Read passphrase from environment

Recommended Usage (Interactive):
  node index.js
  (You will be prompted for mnemonic - it won't be logged)

Scripting Usage:
  echo "your mnemonic phrase here" | node index.js --derive-only

Test Mode:
  node index.js --test

⚠️  SECURITY WARNING:
  - Only use this on an AIR-GAPPED, OFFLINE machine with real mnemonics
  - Never paste real mnemonics into online tools or public repls
  - The --mnemonic flag is insecure (visible in process list and history)
  - Use interactive mode or stdin for production use

Expected Output for Test Mnemonic:
  First address: addr1qy2vzmtlgvjrhkq50rngh8d482zj3l20kyrc6kx4ffl3zfqayfawlf9hwv2fzuygt2km5v92kvf8e3s3mk7ynxw77cwqf7zhh2
`);
}

/**
 * Parse command line arguments
 * @returns {Object} Parsed arguments
 */
function parseArgs() {
  const args = process.argv.slice(2);
  const result = {
    testMode: false,
    mnemonic: null,
    passphrase: "",
    help: false,
    deriveOnly: false,
    noInteractive: false,
  };

  for (let i = 0; i < args.length; i++) {
    switch (args[i]) {
      case "--test":
        result.testMode = true;
        break;
      case "--mnemonic":
        if (i + 1 < args.length) {
          result.mnemonic = args[++i];
          console.warn(
            "⚠️  WARNING: Using --mnemonic is insecure (visible in process list)",
          );
        }
        break;
      case "--passphrase":
        if (i + 1 < args.length) {
          result.passphrase = args[++i];
        }
        break;
      case "--derive-only":
        result.deriveOnly = true;
        break;
      case "--no-interactive":
        result.noInteractive = true;
        break;
      case "--help":
      case "-h":
        result.help = true;
        break;
      default:
        console.error(`Unknown option: ${args[i]}`);
        result.help = true;
    }
  }

  return result;
}

/**
 * Securely read mnemonic from stdin (interactive mode)
 * @returns {Promise<string>} The mnemonic phrase
 */
async function readMnemonicSecurely() {
  const readline = require("readline");

  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  return new Promise((resolve) => {
    console.log(
      "\n⚠️  SECURITY WARNING: Ensure you are on an OFFLINE, air-gapped machine!",
    );
    console.log("Type or paste your mnemonic phrase below:");

    rl.question("Mnemonic (12-24 words): ", (answer) => {
      rl.close();
      resolve(answer);
    });
  });
}

/**
 * Main execution function
 */
async function main() {
  try {
    const args = parseArgs();

    // Show help if requested
    if (args.help) {
      showHelp();
      process.exit(0);
    }

    let mnemonic;
    let passphrase = args.passphrase || process.env.PASSPHRASE || "";

    // Determine mnemonic source
    if (args.testMode) {
      console.log("⚠️  TEST MODE: Using canonical test mnemonic");
      console.log(
        "Expected first address: addr1qy2vzmtlgvjrhkq50rngh8d482zj3l20kyrc6kx4ffl3zfqayfawlf9hwv2fzuygt2km5v92kvf8e3s3mk7ynxw77cwqf7zhh2\n",
      );
      mnemonic =
        "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about";
    } else if (args.mnemonic) {
      mnemonic = args.mnemonic;
    } else if (process.env.MNEMONIC) {
      console.warn("⚠️  WARNING: Using MNEMONIC from environment variable");
      mnemonic = process.env.MNEMONIC;
    } else if (!process.stdin.isTTY) {
      // Reading from pipe/stdin
      const chunks = [];
      for await (const chunk of process.stdin) {
        chunks.push(chunk);
      }
      mnemonic = Buffer.concat(chunks).toString("utf8").trim();
    } else if (!args.deriveOnly && !args.noInteractive) {
      // Interactive mode (only if not in derive-only or no-interactive mode)
      mnemonic = await readMnemonicSecurely();
    } else {
      throw new Error(
        "No mnemonic provided. Use --mnemonic, stdin, or interactive mode.",
      );
    }

    // Validate mnemonic
    mnemonic = validateMnemonic(mnemonic);

    // Generate master key
    const entropy = bip39.mnemonicToEntropy(mnemonic);
    const masterKey = generateLedgerMasterKey(entropy, passphrase);
    const masterString = toHexString(masterKey);

    // Handle derive-only mode (output only the master key)
    if (args.deriveOnly) {
      console.log(masterString);
      process.exit(0);
    }

    // Output result (normal mode)
    console.log(`\nLedger Master Key: ${masterString}`);

    if (!args.testMode) {
      console.log("\n✓ Master key generated successfully");
      console.log(
        "⚠️  Keep this key secure! It can be used to derive all your wallet keys.",
      );
      console.log(
        "Next step: Use convert.sh to generate Cardano addresses and keys\n",
      );
    }

    // Clean up sensitive data from memory
    mnemonic = null;
    passphrase = null;

    process.exit(0);
  } catch (error) {
    console.error(`\n❌ Error: ${error.message}`);

    // Show stack trace in debug mode
    if (process.env.DEBUG) {
      console.error("\nStack trace:");
      console.error(error.stack);
    } else {
      console.error("(Run with DEBUG=1 for detailed error information)");
    }

    process.exit(1);
  }
}

// Run main function if this script is executed directly
if (require.main === module) {
  main();
}

// Export functions for testing/library use
module.exports = {
  generateLedgerMasterKey,
  validateMnemonic,
  toHexString,
  toByteArray,
  hashRepeatedly,
  tweakBits,
};

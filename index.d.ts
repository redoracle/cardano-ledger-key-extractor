/**
 * Type definitions for Cardano Ledger Master Key Generator
 * @module index
 */

/**
 * Converts a hex string to a Uint8Array
 * @param hexString - Hex string to convert
 * @returns Byte array representation
 */
export function toByteArray(hexString: string): Uint8Array;

/**
 * Converts a byte array to hex string
 * @param bytes - Byte array to convert
 * @returns Hex string representation
 */
export function toHexString(bytes: Uint8Array | Buffer): string;

/**
 * Validates a BIP39 mnemonic phrase
 * @param mnemonic - The mnemonic phrase to validate (12, 15, 18, 21, or 24 words)
 * @throws {Error} If mnemonic is invalid
 * @returns Trimmed and validated mnemonic
 */
export function validateMnemonic(mnemonic: string): string;

/**
 * Generates a Ledger-compatible master key from BIP39 entropy
 * 
 * This function implements the Ledger-specific key derivation scheme
 * which is compatible with Ledger hardware wallets. It uses PBKDF2
 * and HMAC-SHA512 to derive a 96-byte master key (64-byte key + 32-byte chain code).
 * 
 * Originally from Adrestia documentation with fixes for correct implementation.
 * 
 * @param seed - BIP39 entropy as hex string
 * @param password - Optional BIP39 passphrase (use empty string "" if none)
 * @returns 96-byte master key (64-byte private key + 32-byte chain code)
 * 
 * @example
 * ```typescript
 * const bip39 = require('bip39');
 * const mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about";
 * const entropy = bip39.mnemonicToEntropy(mnemonic);
 * const masterKey = generateLedgerMasterKey(entropy, "");
 * console.log(toHexString(masterKey));
 * ```
 */
export function generateLedgerMasterKey(seed: string, password: string): Uint8Array;

/**
 * Repeatedly hash until we get a valid ed25519 key
 * 
 * This is part of the Ledger key derivation algorithm. It ensures
 * the generated key satisfies ed25519 requirements by checking
 * specific bit patterns and recursively hashing if needed.
 * 
 * @param message - Message buffer to hash
 * @returns Valid hashed key buffer
 */
export function hashRepeatedly(message: Buffer): Buffer;

/**
 * Apply ed25519 bit tweaks to make a valid signing key
 * 
 * Modifies the key material according to ed25519 requirements:
 * - Clears the lowest 3 bits (makes key divisible by 8)
 * - Clears the highest bit
 * - Sets the highest 2nd bit
 * 
 * @param data - Key data buffer to tweak
 * @returns Tweaked key data buffer (modifies in place and returns)
 */
export function tweakBits(data: Buffer): Buffer;

/**
 * Command-line arguments configuration
 */
export interface CliArgs {
  /** Use canonical test mnemonic */
  testMode: boolean;
  
  /** Mnemonic provided via command line (not recommended) */
  mnemonic: string | null;
  
  /** Optional BIP39 passphrase */
  passphrase: string;
  
  /** Show help message */
  help: boolean;
}

/**
 * Network types supported by Cardano
 */
export type CardanoNetwork = 'mainnet' | 'testnet' | 'preprod' | 'preview';

/**
 * Derivation path configuration
 */
export interface DerivationPath {
  /** Account index (typically 0 for first account) */
  account: number;
  
  /** Address index (0 for first address) */
  addressIndex: number;
  
  /** Full stake path (e.g., "1852H/1815H/0H/2/0") */
  stakePath: string;
  
  /** Full payment path (e.g., "1852H/1815H/0H/0/0") */
  paymentPath: string;
}

/**
 * Tool version information
 */
export interface ToolVersions {
  /** cardano-cli version string */
  cardanoCli: string;
  
  /** cardano-address version string */
  cardanoAddress: string;
  
  /** bech32 tool version (optional) */
  bech32?: string;
}

/**
 * Generated key file information
 */
export interface GeneratedKeys {
  /** Root extended private key file path */
  rootPrivate: string;
  
  /** Stake extended private key file path */
  stakePrivate: string;
  
  /** Stake extended public key file path */
  stakePublic: string;
  
  /** Payment extended private key file path */
  paymentPrivate: string;
  
  /** Payment extended public key file path */
  paymentPublic: string;
  
  /** Cardano-cli stake signing key file path */
  stakeSigningKey: string;
  
  /** Cardano-cli payment signing key file path */
  paymentSigningKey: string;
}

/**
 * Generated address information
 */
export interface GeneratedAddresses {
  /** Payment-only address */
  payment: string;
  
  /** Stake-only address */
  stake: string;
  
  /** Base address (payment + stake delegation) */
  base: string;
  
  /** Candidate base address (for verification) */
  baseCandidate: string;
}

/**
 * Complete generation result
 */
export interface GenerationResult {
  /** Network used for generation */
  network: CardanoNetwork;
  
  /** Derivation paths used */
  paths: DerivationPath;
  
  /** Tool versions used */
  versions: ToolVersions;
  
  /** Generated key files */
  keys: GeneratedKeys;
  
  /** Generated addresses */
  addresses: GeneratedAddresses;
  
  /** Output directory path */
  outputDirectory: string;
  
  /** Generation timestamp */
  timestamp: Date;
  
  /** Whether verification passed (base.addr matches base.addr_candidate) */
  verificationPassed: boolean;
}

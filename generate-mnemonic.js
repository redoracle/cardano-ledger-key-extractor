#!/usr/bin/env node
const bip39 = require('bip39');

// Generate 24-word mnemonic
const mnemonic = bip39.generateMnemonic(256); // 256 bits = 24 words
console.log(mnemonic);

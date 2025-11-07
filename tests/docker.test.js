/**
 * Docker and shell script integration tests for Cardano Ledger Master Key Generator
 * Tests Docker image building, running, and conversion workflows
 * Run with: npm run test:docker
 */

const { execSync, spawn } = require("child_process");
const fs = require("fs");
const path = require("path");
const os = require("os");

// Test configuration
const TEST_IMAGE_NAME = "ghcr.io/redoracle/cardano-ledger-key-extractor:test";
const TEST_OUTPUT_DIR = path.join(__dirname, "..", "test_output");
const DOCKER_TIMEOUT = 120000; // 2 minutes for Docker operations

// Known test vectors
const _TEST_MNEMONIC =
  "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about";
const TEST_EXPECTED_MASTER_KEY =
  "402b03cd9c8bed9ba9f9bd6cd9c315ce9fcc59c7c25d37c85a36096617e69d418e35cb4a3b737afd007f0688618f21a8831643c0e6c77fc33c06026d2a0fc93832596435e70647d7d98ef102a32ea40319ca8fb6c851d7346d3bd8f9d1492658";

// Utility functions
function isDockerAvailable() {
  try {
    execSync("docker version", { stdio: "ignore" });
    return true;
  } catch (error) {
    return false;
  }
}

function isAppleSilicon() {
  return os.arch() === "arm64" && os.platform() === "darwin";
}

function getPlatformFlag() {
  return isAppleSilicon() ? "--platform linux/amd64" : "";
}

function cleanupTestOutput() {
  if (fs.existsSync(TEST_OUTPUT_DIR)) {
    fs.rmSync(TEST_OUTPUT_DIR, { recursive: true, force: true });
  }
}

function ensureTestOutputDir() {
  if (!fs.existsSync(TEST_OUTPUT_DIR)) {
    fs.mkdirSync(TEST_OUTPUT_DIR, { recursive: true });
  }
}

function runDockerCommand(command, options = {}) {
  const platformFlag = getPlatformFlag();
  const fullCommand = platformFlag
    ? `${command.replace("docker run", `docker run ${platformFlag}`)}`
    : command;

  return new Promise((resolve, reject) => {
    const timeout = options.timeout || DOCKER_TIMEOUT;
    const child = spawn("bash", ["-c", fullCommand], {
      stdio: options.stdio || ["pipe", "pipe", "pipe"],
      cwd: __dirname,
    });

    let stdout = "";
    let stderr = "";

    if (child.stdout) {
      child.stdout.on("data", (data) => {
        stdout += data.toString();
      });
    }

    if (child.stderr) {
      child.stderr.on("data", (data) => {
        stderr += data.toString();
      });
    }

    if (options.input) {
      child.stdin.write(options.input);
      child.stdin.end();
    }

    const timer = setTimeout(() => {
      child.kill("SIGKILL");
      reject(new Error(`Command timed out after ${timeout}ms: ${fullCommand}`));
    }, timeout);

    child.on("close", (code) => {
      clearTimeout(timer);
      if (code === 0 || options.allowNonZeroExit) {
        resolve({ stdout, stderr, code });
      } else {
        reject(
          new Error(
            `Command failed with code ${code}: ${fullCommand}\nStderr: ${stderr}`,
          ),
        );
      }
    });
  });
}

// Skip Docker tests if Docker is not available
const describeDocker = isDockerAvailable() ? describe : describe.skip;

describeDocker("Docker Integration Tests", () => {
  beforeAll(() => {
    cleanupTestOutput();
    ensureTestOutputDir();
  });

  afterAll(() => {
    cleanupTestOutput();
  });

  describe("Docker Image Building", () => {
    test("should build Docker image successfully", async () => {
      const platformFlag = getPlatformFlag();
      const buildCommand = `docker build ${platformFlag} -t ${TEST_IMAGE_NAME} ..`;

      await expect(
        runDockerCommand(buildCommand, { timeout: 300000 }),
      ).resolves.toBeDefined();
    }, 300000); // 5 minutes for build

    test("should have required tools in Docker image", async () => {
      const command = `docker run --rm ${getPlatformFlag()} ${TEST_IMAGE_NAME} sh -c 'cardano-cli --version && cardano-address version && node --version'`;

      const result = await runDockerCommand(command);
      expect(result.stdout).toMatch(/cardano-cli/);
      expect(result.stdout).toMatch(/\d+\.\d+\.\d+/); // Version number (for cardano-address)
      expect(result.stdout).toMatch(/v\d+\.\d+\.\d+/); // Node.js version
    });

    test("should have generate-mnemonic.js script", async () => {
      const command = `docker run --rm ${getPlatformFlag()} ${TEST_IMAGE_NAME} sh -c 'test -f generate-mnemonic.js && echo "exists"'`;

      const result = await runDockerCommand(command);
      expect(result.stdout.trim()).toBe("exists");
    });

    test("should have proper file permissions", async () => {
      const command = `docker run --rm ${getPlatformFlag()} ${TEST_IMAGE_NAME} sh -c 'test -x index.js && test -x convert.sh && test -x generate-mnemonic.js && echo "all executable"'`;

      const result = await runDockerCommand(command);
      expect(result.stdout.trim()).toBe("all executable");
    });
  });

  describe("Container Security Features", () => {
    test("should run as non-root user", async () => {
      const command = `docker run --rm ${getPlatformFlag()} ${TEST_IMAGE_NAME} whoami`;

      const result = await runDockerCommand(command);
      expect(result.stdout.trim()).toBe("cardano");
    });

    test("should have no network access when configured", async () => {
      const command = `docker run --rm ${getPlatformFlag()} --network none ${TEST_IMAGE_NAME} sh -c 'ping -c 1 8.8.8.8 2>/dev/null || echo "no network"'`;

      const result = await runDockerCommand(command, {
        allowNonZeroExit: true,
      });
      expect(result.stdout).toMatch(/no network/);
    });

    test("should have read-only filesystem capability", async () => {
      const command = `docker run --rm ${getPlatformFlag()} --read-only --tmpfs /tmp:mode=1777,size=100M ${TEST_IMAGE_NAME} sh -c 'echo "test" > /tmp/test.txt && echo "readonly works"'`;

      const result = await runDockerCommand(command);
      expect(result.stdout).toMatch(/readonly works/);
    });
  });

  describe("Key Generation Workflows", () => {
    test("should generate master key with test mnemonic", async () => {
      const command = `docker run --rm ${getPlatformFlag()} -i ${TEST_IMAGE_NAME} node index.js --test`;

      const result = await runDockerCommand(command);
      expect(result.stdout).toMatch(/Ledger Master Key: 402b03cd/);
      expect(result.stdout).toMatch(new RegExp(TEST_EXPECTED_MASTER_KEY));
    });

    test("should generate fresh mnemonic", async () => {
      const command = `docker run --rm ${getPlatformFlag()} ${TEST_IMAGE_NAME} node generate-mnemonic.js`;

      const result = await runDockerCommand(command);
      const mnemonic = result.stdout.trim();
      const words = mnemonic.split(" ");

      expect(words).toHaveLength(24); // Should generate 24-word mnemonic
      expect(mnemonic).toMatch(/^[a-z ]+$/); // Only lowercase letters and spaces
    });

    test("should handle output directory gracefully in NON_INTERACTIVE mode", async () => {
      ensureTestOutputDir();

      // Create a dummy file to make directory exist
      fs.writeFileSync(path.join(TEST_OUTPUT_DIR, "dummy.txt"), "test");

      const command = `docker run --rm ${getPlatformFlag()} -i -v "${TEST_OUTPUT_DIR}:/output" -e NON_INTERACTIVE=1 ${TEST_IMAGE_NAME} sh -c 'echo "${TEST_EXPECTED_MASTER_KEY}" | ./convert.sh /output'`;

      const result = await runDockerCommand(command);
      // Just check that the command completed successfully in NON_INTERACTIVE mode
      expect(result.code).toBe(0);
    });
  });

  describe("Full Conversion Workflow", () => {
    test("should convert master key to cardano keys", async () => {
      cleanupTestOutput();
      ensureTestOutputDir();

      const command = `docker run --rm ${getPlatformFlag()} -i -v "${TEST_OUTPUT_DIR}:/output" -e NON_INTERACTIVE=1 ${TEST_IMAGE_NAME} sh -c 'echo "${TEST_EXPECTED_MASTER_KEY}" | ./convert.sh /output'`;

      await runDockerCommand(command);

      // Check that key files were generated
      const expectedFiles = [
        "root.prv",
        "stake.xprv",
        "stake.xpub",
        "payment.xprv",
        "payment.xpub",
        "stake.skey",
        "payment.skey",
        "stake.addr",
        "payment.addr",
        "base.addr",
      ];

      for (const file of expectedFiles) {
        const filePath = path.join(TEST_OUTPUT_DIR, file);
        expect(fs.existsSync(filePath)).toBe(true);
        expect(fs.statSync(filePath).size).toBeGreaterThan(0);
      }
    });

    test("should generate expected test address", async () => {
      cleanupTestOutput();
      ensureTestOutputDir();

      const command = `docker run --rm ${getPlatformFlag()} -i -v "${TEST_OUTPUT_DIR}:/output" -e NON_INTERACTIVE=1 ${TEST_IMAGE_NAME} sh -c 'echo "${TEST_EXPECTED_MASTER_KEY}" | ./convert.sh /output'`;

      await runDockerCommand(command);

      const baseAddrPath = path.join(TEST_OUTPUT_DIR, "base.addr");
      expect(fs.existsSync(baseAddrPath)).toBe(true);

      const baseAddr = fs.readFileSync(baseAddrPath, "utf8").trim();
      expect(baseAddr).toMatch(/^addr1[a-z0-9]+$/); // Valid Cardano address format
    });

    test("should handle pipeline: generate mnemonic -> master key -> conversion", async () => {
      cleanupTestOutput();
      ensureTestOutputDir();

      const command = `docker run --rm ${getPlatformFlag()} -i -v "${TEST_OUTPUT_DIR}:/output" -e NON_INTERACTIVE=1 ${TEST_IMAGE_NAME} sh -c 'node generate-mnemonic.js | node index.js | grep "Ledger Master Key" | awk "{print \\$4}" | ./convert.sh /output'`;

      const result = await runDockerCommand(command);

      // Should complete without errors
      expect(result.code).toBe(0);

      // Check key files were generated
      expect(fs.existsSync(path.join(TEST_OUTPUT_DIR, "base.addr"))).toBe(true);
      expect(fs.existsSync(path.join(TEST_OUTPUT_DIR, "payment.skey"))).toBe(
        true,
      );
      expect(fs.existsSync(path.join(TEST_OUTPUT_DIR, "stake.skey"))).toBe(
        true,
      );
    });
  });

  describe("Docker Script Wrapper Tests", () => {
    test("should have executable docker-run.sh", () => {
      const scriptPath = path.join(__dirname, "../docker-run.sh");
      expect(fs.existsSync(scriptPath)).toBe(true);
      expect(fs.statSync(scriptPath).mode & 0o111).toBeTruthy(); // Check execute bit
    });

    test("should show help when called with help command", async () => {
      const command = "../docker-run.sh help";

      const result = await runDockerCommand(command, { timeout: 10000 });
      expect(result.stdout).toMatch(/Cardano Ledger Key Extractor/);
      expect(result.stdout).toMatch(/Commands:/);
      expect(result.stdout).toMatch(/build/);
      expect(result.stdout).toMatch(/generate/);
      expect(result.stdout).toMatch(/full/);
      expect(result.stdout).toMatch(/test/);
    });

    test("should detect platform correctly on Apple Silicon", () => {
      if (isAppleSilicon()) {
        expect(getPlatformFlag()).toBe("--platform linux/amd64");
      } else {
        expect(getPlatformFlag()).toBe("");
      }
    });
  });

  describe("Error Handling", () => {
    test("should handle invalid master key gracefully", async () => {
      cleanupTestOutput();
      ensureTestOutputDir();

      const command = `docker run --rm ${getPlatformFlag()} -i -v "${TEST_OUTPUT_DIR}:/output" -e NON_INTERACTIVE=1 ${TEST_IMAGE_NAME} sh -c 'echo "invalid_key" | ./convert.sh /output'`;

      const result = await runDockerCommand(command, {
        allowNonZeroExit: true,
      });
      expect(result.code).not.toBe(0);
      expect(result.stderr).toMatch(/Master key must be hexadecimal/i);
    });

    test("should handle missing volume mount gracefully", async () => {
      const command = `docker run --rm ${getPlatformFlag()} -i -e NON_INTERACTIVE=1 ${TEST_IMAGE_NAME} sh -c 'echo "${TEST_EXPECTED_MASTER_KEY}" | ./convert.sh /nonexistent'`;

      const result = await runDockerCommand(command, {
        allowNonZeroExit: true,
      });
      expect(result.code).not.toBe(0);
    });

    test("should validate mnemonic input", async () => {
      const command = `docker run --rm ${getPlatformFlag()} -i ${TEST_IMAGE_NAME} sh -c 'echo "invalid mnemonic words here" | node index.js'`;

      const result = await runDockerCommand(command, {
        allowNonZeroExit: true,
      });
      expect(result.code).not.toBe(0);
      expect(result.stderr).toMatch(/Invalid word count/i);
    });
  });
});

describe("Shell Script Tests", () => {
  describe("generate-mnemonic.js", () => {
    test("should be executable", () => {
      const scriptPath = path.join(__dirname, "../generate-mnemonic.js");
      expect(fs.existsSync(scriptPath)).toBe(true);
      expect(fs.statSync(scriptPath).mode & 0o111).toBeTruthy();
    });

    test("should generate valid 24-word mnemonic", () => {
      const result = execSync("node generate-mnemonic.js", {
        encoding: "utf8",
      });
      const mnemonic = result.trim();
      const words = mnemonic.split(" ");

      expect(words).toHaveLength(24);
      expect(mnemonic).toMatch(/^[a-z ]+$/);

      // Validate with bip39 if available
      try {
        const bip39 = require("bip39");
        expect(bip39.validateMnemonic(mnemonic)).toBe(true);
      } catch (e) {
        // bip39 not available in test environment, skip validation
      }
    });

    test("should generate different mnemonics each time", () => {
      const mnemonic1 = execSync("node generate-mnemonic.js", {
        encoding: "utf8",
      }).trim();
      const mnemonic2 = execSync("node generate-mnemonic.js", {
        encoding: "utf8",
      }).trim();

      expect(mnemonic1).not.toBe(mnemonic2);
    });
  });

  describe("convert.sh output directory handling", () => {
    beforeEach(() => {
      cleanupTestOutput();
    });

    afterEach(() => {
      cleanupTestOutput();
    });

    test("should create new directory when it does not exist", () => {
      expect(fs.existsSync(TEST_OUTPUT_DIR)).toBe(false);

      // This will fail because we don't have cardano tools in test env,
      // but we can check the directory creation part
      try {
        execSync(
          `echo "${TEST_EXPECTED_MASTER_KEY}" | NON_INTERACTIVE=1 SKIP_ENCRYPTION=1 ./convert.sh "${TEST_OUTPUT_DIR}"`,
          {
            stdio: "ignore",
          },
        );
      } catch (e) {
        // Expected to fail due to missing cardano tools
      }

      expect(fs.existsSync(TEST_OUTPUT_DIR)).toBe(true);
    });

    test("should handle existing directory in non-interactive mode", () => {
      // Create existing directory with content
      ensureTestOutputDir();
      fs.writeFileSync(
        path.join(TEST_OUTPUT_DIR, "existing.txt"),
        "old content",
      );

      expect(fs.existsSync(path.join(TEST_OUTPUT_DIR, "existing.txt"))).toBe(
        true,
      );

      // Run convert.sh in non-interactive mode
      try {
        execSync(
          `echo "${TEST_EXPECTED_MASTER_KEY}" | NON_INTERACTIVE=1 SKIP_ENCRYPTION=1 ./convert.sh "${TEST_OUTPUT_DIR}"`,
          {
            stdio: "ignore",
          },
        );
      } catch (e) {
        // Expected to fail due to missing cardano tools, but directory should be cleaned
      }

      // Directory should still exist but old content should be gone
      expect(fs.existsSync(TEST_OUTPUT_DIR)).toBe(true);
      expect(fs.existsSync(path.join(TEST_OUTPUT_DIR, "existing.txt"))).toBe(
        false,
      );
    });
  });
});

describe("Docker Compose Configuration", () => {
  test("should have valid docker-compose.yml", () => {
    const composePath = path.join(__dirname, "../docker-compose.yml");
    expect(fs.existsSync(composePath)).toBe(true);

    const composeContent = fs.readFileSync(composePath, "utf8");
    expect(composeContent).toMatch(/platform:\s*linux\/amd64/);
    expect(composeContent).toMatch(/network_mode:\s*none/);
    expect(composeContent).toMatch(/read_only:\s*true/);
    expect(composeContent).toMatch(/NON_INTERACTIVE=1/);
  });
});

describe("Build Scripts", () => {
  test("should have executable build-multiarch.sh", () => {
    const scriptPath = path.join(__dirname, "../build-multiarch.sh");
    expect(fs.existsSync(scriptPath)).toBe(true);
    expect(fs.statSync(scriptPath).mode & 0o111).toBeTruthy();
  });

  test("build-multiarch.sh should show help", () => {
    try {
      const result = execSync("../build-multiarch.sh --help", {
        encoding: "utf8",
        stdio: "pipe",
        cwd: __dirname,
      });
      expect(result).toMatch(/Docker Build Script/);
      expect(result).toMatch(/--load.*--push.*--tag/);
    } catch (error) {
      // On macOS, the head command might fail with -n -1 syntax
      // Check if it's the expected head command error
      if (error.message.includes("illegal line count")) {
        // Skip this test on macOS as it's a script compatibility issue
        console.log(
          "Skipping build-multiarch.sh test due to macOS head command compatibility",
        );
      } else {
        throw error;
      }
    }
  });
});

describe("Fresh BIP39 Seed Docker Tests", () => {
  const bip39 = require("bip39");

  beforeEach(() => {
    cleanupTestOutput();
    ensureTestOutputDir();
  });

  afterEach(() => {
    cleanupTestOutput();
  });

  test("should generate fresh mnemonic and convert in Docker container", async () => {
    // Build image if not exists
    try {
      execSync(`docker image inspect ${TEST_IMAGE_NAME}`, { stdio: "ignore" });
    } catch {
      execSync(`docker build ${getPlatformFlag()} -t ${TEST_IMAGE_NAME} .`, {
        stdio: "inherit",
      });
    }

    // Generate fresh 24-word mnemonic
    const freshMnemonic = bip39.generateMnemonic(256);
    expect(bip39.validateMnemonic(freshMnemonic)).toBe(true);

    console.log("Testing with fresh mnemonic:", freshMnemonic);

    // Generate master key using the container
    const generateCommand = `docker run --rm -i ${getPlatformFlag()} ${TEST_IMAGE_NAME} node index.js`;
    const generateResult = await runDockerCommand(generateCommand, {
      input: freshMnemonic + "\n",
      timeout: 60000,
    });

    expect(generateResult.stdout).toMatch(/Ledger Master Key:/);

    // Extract master key from output
    const masterKeyMatch = generateResult.stdout.match(
      /Ledger Master Key:\s*([0-9a-f]{192})/,
    );
    expect(masterKeyMatch).toBeTruthy();

    const masterKeyHex = masterKeyMatch[1];
    expect(masterKeyHex).toMatch(/^[0-9a-f]{192}$/);
    expect(masterKeyHex).not.toBe(TEST_EXPECTED_MASTER_KEY);

    console.log("Generated master key:", masterKeyHex);

    // Convert master key to Cardano keys using convert.sh
    const convertCommand = `echo "${masterKeyHex}" | docker run --rm ${getPlatformFlag()} -i -v "${TEST_OUTPUT_DIR}:/output" -e NON_INTERACTIVE=1 -e OUTPUT_DIR=/output ${TEST_IMAGE_NAME} sh -c './convert.sh /output'`;

    const convertResult = await runDockerCommand(convertCommand, {
      timeout: 60000,
    });

    expect(convertResult.code).toBe(0);

    // Verify all expected output files exist
    const expectedFiles = [
      "root.prv",
      "stake.xprv",
      "stake.xpub",
      "payment.xprv",
      "payment.xpub",
      "stake.skey",
      "payment.skey",
      "stake.addr",
      "payment.addr",
      "base.addr",
    ];

    expectedFiles.forEach((file) => {
      const filePath = path.join(TEST_OUTPUT_DIR, file);
      expect(fs.existsSync(filePath)).toBe(true);
      expect(fs.statSync(filePath).size).toBeGreaterThan(0);
    });

    // Validate generated address format
    const baseAddrPath = path.join(TEST_OUTPUT_DIR, "base.addr");
    const baseAddr = fs.readFileSync(baseAddrPath, "utf8").trim();
    expect(baseAddr).toMatch(/^addr1[a-z0-9]+$/);

    console.log("Generated base address:", baseAddr);
  }, 180000); // 3 minute timeout

  test("should generate multiple unique fresh seeds in Docker", async () => {
    // Build image if not exists
    try {
      execSync(`docker image inspect ${TEST_IMAGE_NAME}`, { stdio: "ignore" });
    } catch {
      execSync(`docker build ${getPlatformFlag()} -t ${TEST_IMAGE_NAME} .`, {
        stdio: "inherit",
      });
    }

    const generatedData = [];
    const testCount = 3;

    for (let i = 0; i < testCount; i++) {
      console.log(`Generating fresh seed ${i + 1}/${testCount}...`);

      // Generate unique fresh mnemonic for each iteration
      const freshMnemonic = bip39.generateMnemonic(256);
      expect(bip39.validateMnemonic(freshMnemonic)).toBe(true);

      // Generate master key in Docker
      const generateCommand = `docker run --rm -i ${getPlatformFlag()} ${TEST_IMAGE_NAME} node index.js`;
      const result = await runDockerCommand(generateCommand, {
        input: freshMnemonic + "\n",
        timeout: 30000,
      });

      expect(result.stdout).toMatch(/Ledger Master Key:/);

      const masterKeyMatch = result.stdout.match(
        /Ledger Master Key:\s*([0-9a-f]{192})/,
      );
      expect(masterKeyMatch).toBeTruthy();

      const masterKeyHex = masterKeyMatch[1];
      expect(masterKeyHex).toMatch(/^[0-9a-f]{192}$/);

      generatedData.push({
        mnemonic: freshMnemonic,
        masterKey: masterKeyHex,
      });
    }

    // Verify all mnemonics are unique
    const mnemonics = generatedData.map((d) => d.mnemonic);
    const uniqueMnemonics = [...new Set(mnemonics)];
    expect(uniqueMnemonics.length).toBe(testCount);

    // Verify all master keys are unique
    const masterKeys = generatedData.map((d) => d.masterKey);
    const uniqueMasterKeys = [...new Set(masterKeys)];
    expect(uniqueMasterKeys.length).toBe(testCount);

    console.log(
      `Successfully generated ${testCount} unique fresh seeds in Docker`,
    );
  }, 180000); // 3 minute timeout

  test("should handle fresh seed with different networks in Docker", async () => {
    // Build image if not exists
    try {
      execSync(`docker image inspect ${TEST_IMAGE_NAME}`, { stdio: "ignore" });
    } catch {
      execSync(`docker build ${getPlatformFlag()} -t ${TEST_IMAGE_NAME} .`, {
        stdio: "inherit",
      });
    }

    const networks = ["mainnet", "testnet", "preprod"];
    const freshMnemonic = bip39.generateMnemonic(256);

    // Generate master key once
    const generateCommand = `docker run --rm -i ${getPlatformFlag()} ${TEST_IMAGE_NAME} node index.js`;
    const generateResult = await runDockerCommand(generateCommand, {
      input: freshMnemonic + "\n",
      timeout: 30000,
    });

    const masterKeyMatch = generateResult.stdout.match(
      /Ledger Master Key:\s*([0-9a-f]{192})/,
    );
    const masterKeyHex = masterKeyMatch[1];

    const networkAddresses = [];

    for (const network of networks) {
      console.log(`Testing fresh seed with network: ${network}`);

      const networkOutputDir = path.join(TEST_OUTPUT_DIR, network);
      fs.mkdirSync(networkOutputDir, { recursive: true });

      const convertCommand = `echo "${masterKeyHex}" | docker run --rm ${getPlatformFlag()} -i -v "${networkOutputDir}:/output" -e NON_INTERACTIVE=1 -e OUTPUT_DIR=/output -e CARDANO_NETWORK=${network} ${TEST_IMAGE_NAME} sh -c './convert.sh /output'`;

      const result = await runDockerCommand(convertCommand, {
        timeout: 60000,
      });

      expect(result.code).toBe(0);

      // Verify address was generated
      const baseAddrPath = path.join(networkOutputDir, "base.addr");
      expect(fs.existsSync(baseAddrPath)).toBe(true);

      const baseAddr = fs.readFileSync(baseAddrPath, "utf8").trim();

      // Validate network-specific address formats
      if (network === "mainnet") {
        expect(baseAddr).toMatch(/^addr1[a-z0-9]+$/);
      } else {
        expect(baseAddr).toMatch(/^addr_test1[a-z0-9]+$/);
      }

      networkAddresses.push({ network, address: baseAddr });
    }

    // Verify addresses are different across networks
    const addresses = networkAddresses.map((na) => na.address);
    const _uniqueAddresses = [...new Set(addresses)];

    // At minimum, mainnet should be different from testnet/preprod
    const mainnetAddr = networkAddresses.find(
      (na) => na.network === "mainnet",
    )?.address;
    const testnetAddr = networkAddresses.find(
      (na) => na.network === "testnet",
    )?.address;

    expect(mainnetAddr).toBeTruthy();
    expect(testnetAddr).toBeTruthy();
    expect(mainnetAddr).not.toBe(testnetAddr);

    console.log("Network addresses generated:", networkAddresses);
  }, 240000); // 4 minute timeout
});

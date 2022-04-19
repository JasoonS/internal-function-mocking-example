require("hardhat-spdx-license-identifier");
require("@tenderly/hardhat-tenderly"); // https://hardhat.org/plugins/tenderly-hardhat-tenderly.html
require("solidity-coverage");
// require("@openzeppelin/hardhat-upgrades");
require("./hardhat-plugins/codegen");
require("@float-capital/hardhat-deploy");
require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-etherscan");

let config;
try {
  config = require("./secretsManager.js");
} catch (e) {
  console.error("You are using the example secrets manager, please copy this file if you want to use it")
  config = require("./secretsManager.example.js");
}

const {
  mnemonic,
  mainnetProviderUrl,
  rinkebyProviderUrl,
  kovanProviderUrl,
  goerliProviderUrl,
  etherscanApiKey,
  polygonscanApiKey,
  mumbaiProviderUrl,
} = config;

let runCoverage =
  !process.env.DONT_RUN_REPORT_SUMMARY ||
  process.env.DONT_RUN_REPORT_SUMMARY.toUpperCase() != "TRUE";
if (runCoverage) {
  require("hardhat-gas-reporter");
}
require("hardhat-abi-exporter");
let isWaffleTest =
  !!process.env.WAFFLE_TEST && process.env.WAFFLE_TEST.toUpperCase() == "TRUE";

require("@nomiclabs/hardhat-waffle");


// This is a sample Buidler task. To learn how to create your own go to
// https://buidler.dev/guides/create-task.html
task("accounts", "Prints the list of accounts", async () => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(await account.getAddress());
  }
});

// You have to export an object to set up your config
// This object can have the following optional entries:
// defaultNetwork, networks, solc, and paths.
// Go to https://buidler.dev/config/ to learn more
module.exports = {
  // This is a sample solc configuration that specifies which version of solc to use
  solidity: {
    version: "0.8.13",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
    },
    ganache: {
      url: "http://localhost:8545",
    },
    mumbai: {
      chainId: 80001,
      url: mumbaiProviderUrl || "https://rpc-mumbai.maticvigil.com/v1",
    },
  },
  paths: {
    tests: isWaffleTest ? "./test" : "./test",
  },
  namedAccounts: {
    deployer: {
      default: 0, // here this will by default take the first account as deployer
      1: 0, // similarly on mainnet it will take the first account as deployer. Note though that depending on how hardhat network are configured, the account 0 on one network can be different than on another
    },
    admin: {
      default: 1,
    },
    user1: {
      default: 2,
    },
    user2: {
      default: 3,
    },
    user3: {
      default: 4,
    },
    user4: {
      default: 5,
    },
  },
  gasReporter: {
    // Disabled by default for faster running of tests
    enabled: true,
    currency: "USD",
    gasPrice: 80,
    coinmarketcap: "9aacee3e-7c04-4978-8f93-63198c0fbfef",
  },
  spdxLicenseIdentifier: {
    // Set these to true if you ever want to change the licence on all of the contracts (by changing it in package.json)
    overwrite: false,
    runOnCompile: false,
  },
  abiExporter: {
    path: "./abis",
    clear: true,
    flat: true,
    runOnCompile: true,
    only: [
      ":ERC20Mock$",
      ":YieldManagerMock$",
      ":LongShort$",
      ":SyntheticToken$",
      ":YieldManagerAave$",
      ":YieldManagerAaveBasic$",
      ":FloatCapital_v0$",
      ":Migrations$",
      ":TokenFactory$",
      ":FloatToken$",
      ":Staker$",
      ":Treasury_v0$",
      ":OracleManager$",
      ":OracleManagerChainlink$",
      ":OracleManagerChainlinkTestnet$",
      ":OracleManagerMock$",
      ":LendingPoolAaveMock$",
      ":LendingPoolAddressesProviderMock$",
      ":AaveIncentivesControllerMock$",
      "Mockable$",
    ],
    spacing: 2,
  },
  docgen: {
    path: "./contract-docs",
    only: [
      "^contracts/LongShort",
      "^contracts/Staker",
      "^contracts/FloatToken",
      "^contracts/SyntheticToken",
      "^contracts/TokenFactory",
      "^contracts/YieldManagerAave",
    ],
  },
};

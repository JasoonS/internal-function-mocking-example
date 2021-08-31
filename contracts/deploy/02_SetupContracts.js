const { runTestTransactions } = require("../deployTests/RunTestTransactions");
const {
  runMumbaiTransactions,
} = require("../deployTests/RunMumbaiTransactions");
const { ethers } = require("hardhat");

const {
  STAKER,
  COLLATERAL_TOKEN,
  TREASURY,
  LONGSHORT,
  FLOAT_TOKEN,
  TOKEN_FACTORY,
  FLOAT_CAPITAL,
} = require("../helper-hardhat-config");

module.exports = async ({ getNamedAccounts, deployments }) => {
  console.log("setup contracts");
  const { admin } = await getNamedAccounts();

  /////////////////////////
  //Retrieve Deployments//
  ////////////////////////
  let paymentTokenAddress;
  if (network.name == "mumbai") {
    paymentTokenAddress = "0x001B3B4d0F3714Ca98ba10F6042DaEbF0B1B7b6F";
  } else if (network.name == "hardhat" || network.name == "ganache") {
    paymentTokenAddress = (await deployments.get(COLLATERAL_TOKEN)).address;
  }
  const paymentToken = await ethers.getContractAt(
    COLLATERAL_TOKEN,
    paymentTokenAddress
  );

  const LongShort = await deployments.get(LONGSHORT);
  const longShort = await ethers.getContractAt(LONGSHORT, LongShort.address);

  const Treasury = await deployments.get(TREASURY);
  const treasury = await ethers.getContractAt(TREASURY, Treasury.address);

  const TokenFactory = await deployments.get(TOKEN_FACTORY);
  const tokenFactory = await ethers.getContractAt(
    TOKEN_FACTORY,
    TokenFactory.address
  );

  const Staker = await deployments.get(STAKER);
  const staker = await ethers.getContractAt(STAKER, Staker.address);

  const FloatToken = await deployments.get(FLOAT_TOKEN);
  const floatToken = await ethers.getContractAt(
    FLOAT_TOKEN,
    FloatToken.address
  );

  const FloatCapital = await deployments.get(FLOAT_CAPITAL);
  const floatCapital = await ethers.getContractAt(
    FLOAT_CAPITAL,
    FloatCapital.address
  );
  ///////////////////////////
  //Initialize the contracts/
  ///////////////////////////
  await longShort.initialize(admin, tokenFactory.address, staker.address);

  await floatToken.initialize("Float", "FLT", staker.address);

  await staker.initialize(
    admin,
    longShort.address,
    floatToken.address,
    treasury.address,
    floatCapital.address,
    "250000000000000000" //25%
  );

  console.log("before test txs");
  if (network.name == "mumbai") {
    console.log("mumbai test transactions");
    await runMumbaiTransactions({
      staker,
      longShort: longShort.connect(admin),
      paymentToken,
      treasury,
    });
  } else if (network.name == "hardhat" || network.name == "ganache") {
    console.log("mumbai test transactions");
    await runTestTransactions({
      staker,
      longShort: longShort.connect(admin),
      paymentToken,
      treasury,
    });
  }
  console.log("after test txs");
};
module.exports.tags = ["all", "setup"];

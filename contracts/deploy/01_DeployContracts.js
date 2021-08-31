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
  const { deploy } = deployments;
  const { deployer, admin } = await getNamedAccounts();

  let paymentToken;

  if (network.name != "mumbai") {
    console.log(network.name);
    paymentToken = await deploy(COLLATERAL_TOKEN, {
      from: deployer,
      log: true,
      args: ["dai token", "DAI"],
    });
    console.log("dai address", paymentToken.address);
  }

  console.log("Deploying contracts with the account:", deployer);
  console.log("Admin Account:", admin);

  await deploy(TREASURY, {
    from: deployer,
    proxy: {
      proxyContract: "UUPSProxy",
      execute: {
        methodName: "initialize",
        args: [admin],
      },
    },
    log: true,
  });

  await deploy(FLOAT_CAPITAL, {
    from: deployer,
    proxy: {
      proxyContract: "UUPSProxy",
      execute: {
        methodName: "initialize",
        args: [admin],
      },
    },
    log: true,
  });

  await deploy(STAKER, {
    from: deployer,
    log: true,
    proxy: {
      proxyContract: "UUPSProxy",
      initializer: false,
    },
  });

  const longShort = await deploy(LONGSHORT, {
    from: deployer,
    log: true,
    proxy: {
      proxyContract: "UUPSProxy",
      initializer: false,
    },
  });

  await deploy(TOKEN_FACTORY, {
    from: admin,
    log: true,
    args: [longShort.address],
  });

  await deploy(FLOAT_TOKEN, {
    from: deployer,
    log: true,
    proxy: {
      proxyContract: "UUPSProxy",
      initializer: false,
    },
  });
};
module.exports.tags = ["all", "contracts"];

const fs = require("fs");
const path = require("path");
const env = require("./env");
const { exec } = require("child_process");

const prefix = env.openZeppelinDir;

const args = process.argv.splice(2);

// PASS IN THE NETWORKS AS ARGS e.g. node scripts/verify.js goerli binanceTest
// if none passed verifies for all the networks it's configured ofr
let networks;
if (args.length > 0) {
  networks = args;
} else {
  networks = Object.keys(env.networksToOpenZeppelin);
}

networks
  .filter((x) => x.network !== "ganache")
  .forEach((network) => {
    try {
      input = fs
        .readFileSync(path.join(prefix, env.networksToOpenZeppelin[network]))
        .toString();
    } catch (e) {
      console.log(e);
      return;
    }

    const inpObj = JSON.parse(input);
    console.log(network, inpObj.proxies);
    let variables = {
      // ...process.env,
      NETWORK: network,
    };
    Object.keys(env.implementationVarsToProxies).forEach((x) => {
      console.log(x, env.implementationVarsToProxies[x]);
      variables[x] =
        inpObj.proxies[env.implementationVarsToProxies[x]][0].implementation;
    });

    console.log(
      `NETWORK=${variables.NETWORK} LONGSHORT_IMPLEMENTATION=${variables.LONGSHORT_IMPLEMENTATION} TREASURY_IMPLEMENTATION=${variables.TREASURY_IMPLEMENTATION} FLOAT_CAPITAL_IMPLEMENTATION=${variables.FLOAT_CAPITAL_IMPLEMENTATION} STAKER_IMPLEMENTATION=${variables.STAKER_IMPLEMENTATION} yarn verify-contracts`
    );
    exec(
      `cd contracts; yarn verify-contracts`,
      {
        env: variables,
      },
      (error, stdout) => {
        console.log(`VERIFYING FOR ${network}`);
        if (error) {
          console.log(error);
          console.log(stdout);
        } else {
          console.log(`Successfully verified contracts for  ${network}`);
        }
      }
    );
  });

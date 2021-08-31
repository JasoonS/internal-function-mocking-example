const fs = require("fs");
const path = require("path");

let output = {};

const dir = "./contracts/buildsDeployed/deployed";
const files = fs.readdirSync(dir);
files.map((file) => {
  const data = fs.readFileSync(path.join(dir, file));
  const build = JSON.parse(data.toString());
  if (build.contractName == "migrations") {
    return;
  }

  Object.keys(build.networks).forEach((networkId) => {
    output[networkId] = output[networkId] || {};
    output[networkId][build.contractName] = build.networks[networkId].address;
  });
});

if (typeof output["42"] === "object") {
  output["42"]["Dai"] = "0xff795577d9ac8bd7d90ee22b6c1703490b6512fd";
}
console.log(JSON.stringify(output, null, 2));

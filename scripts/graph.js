const fs = require("fs");
const path = require("path");
const env = require("./env");

// PASS IN THE NETWORKS AS ARGS e.g. node scripts/verify.js goerli binanceTest
// if none passed verifies for all the networks it's configured of
const args = process.argv.splice(2);
let openzeppelin;
if (args.length > 0) {
  openzeppelin = args.map((x) => env.networksToOpenZeppelin[x]);
} else {
  openzeppelin = Object.keys(env.openZeppelinToYaml);
}

const longShortAddressKey = "<long-short-address>";
const stakerAddressKey = "<staker-address>";

const preserveKeys = [
  "<network>",
  "<start-block>",
  "<staker-network>",
  "<staker-start-block>",
];

const prefix = env.openZeppelinDir;
const graphPath = "./graph";

const templateName = "subgraph.template.yaml";

const addAddressLongShort = (template, input) => {
  const address = `"${
    JSON.parse(input).proxies["float-capital/LongShort"][0].address
  }"`;
  return template.replace(longShortAddressKey, address);
};

const addAddressStaker = (template, input) => {
  const address = `"${
    JSON.parse(input).proxies["float-capital/Staker"][0].address
  }"`;
  return template.replace(stakerAddressKey, address);
};

const preserveValues = (template, output) => {
  templateLines = template.split("\n");
  outputLines = output.split("\n");
  preserveKeys.forEach((p) => {
    const i = templateLines.findIndex((l) => l.includes(p));
    if (i != -1) {
      templateVal = outputLines[i].split(":")[1].trim();
      template = template.replace(p, templateVal);
      template = template.replace(p, templateVal);
      template = template.replace(p, templateVal);
      // template = template.replaceAll(p, templateVal); // `replaceAll` only exists in javascript v15 or newer
    }
  });
  return template;
};

openzeppelin.forEach((file) => {
  let input, output, template;
  try {
    input = fs.readFileSync(path.join(prefix, file)).toString();
    template = fs.readFileSync(path.join(graphPath, templateName)).toString();
    output = fs
      .readFileSync(path.join(graphPath, env.openZeppelinToYaml[file]))
      .toString();
  } catch (e) {
    console.log(e);
    return;
  }
  template = addAddressLongShort(template, input);
  template = addAddressStaker(template, input);
  template = preserveValues(template, output);
  fs.writeFileSync(
    path.join(graphPath, env.openZeppelinToYaml[file]),
    template
  );
});

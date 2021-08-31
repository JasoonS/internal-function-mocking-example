module.exports = {
  openZeppelinDir: "./contracts/.openzeppelin",
  openZeppelinToYaml: {
    "dev-97.json": "subgraph.binance-test.yaml",
    "dev-321.json": "subgraph.ganache.yaml",
  },
  networksToOpenZeppelin: {
    binanceTest: "dev-97.json",
    ganache: "dev-321.json",
  },
  implementationVarsToProxies: {
    LONGSHORT_IMPLEMENTATION: "float-capital/LongShort",
    STAKER_IMPLEMENTATION: "float-capital/Staker",
    TREASURY_IMPLEMENTATION: "float-capital/Treasury",
    FLOAT_CAPITAL_IMPLEMENTATION: "float-capital/FloatCapital",
  },
};

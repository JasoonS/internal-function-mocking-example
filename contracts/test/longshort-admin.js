const {
  BN,
  expectRevert,
  ether,
  expectEvent,
  balance,
  time,
} = require("@openzeppelin/test-helpers");

const { initialize, createSynthetic } = require("./helpers");

contract("LongShort (admin)", (accounts) => {
  let longShort;
  let marketIndex;
  let treasury;

  const syntheticName = "FTSE100";
  const syntheticSymbol = "FTSE";

  // Fees
  const _baseEntryFee = 0;
  const _badLiquidityEntryFee = 0;
  const _baseExitFee = 50;
  const _badLiquidityExitFee = 50;

  // Default test values
  const admin = accounts[0];
  const user1 = accounts[1];

  const zeroAddressStr = "0x0000000000000000000000000000000000000000";

  const adminRoleBytesStr =
    "0xa49807205ce4d355092ef5a8a18f56e8913cf4a201fbe287825b095693c21775";

  beforeEach(async () => {
    const result = await initialize(admin);

    longShort = result.longShort;
    treasury = result.treasury;

    const synthResult = await createSynthetic(
      admin,
      longShort,
      syntheticName,
      syntheticSymbol,
      treasury,
      _baseEntryFee,
      _badLiquidityEntryFee,
      _baseExitFee,
      _badLiquidityExitFee
    );

    marketIndex = synthResult.currentMarketIndex;
  });

  it("<IMPLEMENTED IN WAFFLE> shouldn't allow non admin to update the oracle", async () => {
    const newOracleAddress = zeroAddressStr;

    await expectRevert(
      longShort.updateMarketOracle(marketIndex, newOracleAddress, {
        from: user1,
      }),
      `AccessControl: account ${user1.toLowerCase()} is missing role ${adminRoleBytesStr}`
    );
  });

  it("should allow the admin to update the oracle correctly", async () => {
    const newOracleAddress = zeroAddressStr;

    await longShort.updateMarketOracle(marketIndex, newOracleAddress, {
      from: admin,
    });

    const adminIsContractAdmin = await longShort.hasRole(
      adminRoleBytesStr,
      admin
    );

    assert(adminIsContractAdmin, "is admin");

    const updatedOracleAddress = await longShort.oracleManagers.call(
      marketIndex
    );

    assert.equal(
      newOracleAddress,
      updatedOracleAddress,
      "Oracle has been updated"
    );
  });
});

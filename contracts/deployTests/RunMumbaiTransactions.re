open LetOps;
open DeployHelpers;
open Globals;

type allContracts = {
  staker: Staker.t,
  longShort: LongShort.t,
  paymentToken: ERC20Mock.t,
  treasury: Treasury_v0.t,
  syntheticToken: SyntheticToken.t,
};

let runMumbaiTransactions = ({longShort, treasury, paymentToken}) => {
  let%Await loadedAccounts = Ethers.getSigners();

  let admin = loadedAccounts->Array.getUnsafe(1);
  let user1 = loadedAccounts->Array.getUnsafe(2);
  let user2 = loadedAccounts->Array.getUnsafe(3);
  let user3 = loadedAccounts->Array.getUnsafe(4);

  let%AwaitThen _ = DeployHelpers.topupBalanceIfLow(~from=admin, ~to_=user1);
  let%AwaitThen _ = DeployHelpers.topupBalanceIfLow(~from=admin, ~to_=user2);
  let%AwaitThen _ = DeployHelpers.topupBalanceIfLow(~from=admin, ~to_=user3);
  Js.log("deploying markets");

  let%AwaitThen _ =
    deployMumbaiMarket(
      ~syntheticName="ETH Market",
      ~syntheticSymbol="FL_ETH",
      ~longShortInstance=longShort,
      ~treasuryInstance=treasury,
      ~admin,
      ~paymentToken: ERC20Mock.t,
      ~oraclePriceFeedAddress=ChainlinkOracleAddresses.Mumbai.ethOracleChainlink,
    );

  let%AwaitThen _ =
    deployMumbaiMarket(
      ~syntheticName="MATIC Market",
      ~syntheticSymbol="FL_MATIC",
      ~longShortInstance=longShort,
      ~treasuryInstance=treasury,
      ~admin,
      ~paymentToken: ERC20Mock.t,
      ~oraclePriceFeedAddress=ChainlinkOracleAddresses.Mumbai.maticOracleChainlink,
    );

  let%AwaitThen _ =
    deployMumbaiMarket(
      ~syntheticName="BTC Market",
      ~syntheticSymbol="FL_BTC",
      ~longShortInstance=longShort,
      ~treasuryInstance=treasury,
      ~admin,
      ~paymentToken: ERC20Mock.t,
      ~oraclePriceFeedAddress=ChainlinkOracleAddresses.Mumbai.btcOracleChainlink,
    );

  let initialMarkets = [|1, 2, 3|];

  let longMintAmount = bnFromString("10000000000000000000");
  let shortMintAmount = longMintAmount->div(bnFromInt(2));
  let redeemShortAmount = shortMintAmount->div(bnFromInt(2));
  let longStakeAmount = bnFromInt(1);

  let priceAndStateUpdate = () => {
    let%AwaitThen _ =
      executeOnMarkets(
        initialMarkets,
        setOracleManagerPrice(~longShort, ~marketIndex=_, ~admin),
      );

    Js.log("Executing update system state");

    executeOnMarkets(
      initialMarkets,
      updateSystemState(~longShort, ~admin, ~marketIndex=_),
    );
  };

  Js.log("Executing Long Mints");
  let%AwaitThen _ =
    executeOnMarkets(
      initialMarkets,
      mintLongNextPriceWithSystemUpdate(
        ~amount=longMintAmount,
        ~marketIndex=_,
        ~paymentToken,
        ~longShort,
        ~user=user1,
        ~admin,
      ),
    );

  Js.log("Executing Short Mints");
  let%AwaitThen _ =
    executeOnMarkets(
      initialMarkets,
      mintShortNextPriceWithSystemUpdate(
        ~amount=shortMintAmount,
        ~marketIndex=_,
        ~paymentToken,
        ~longShort,
        ~user=user1,
        ~admin,
      ),
    );

  Js.log("Executing Short Position Redeem");
  let%AwaitThen _ =
    executeOnMarkets(
      initialMarkets,
      redeemShortNextPriceWithSystemUpdate(
        ~amount=redeemShortAmount,
        ~marketIndex=_,
        ~longShort,
        ~user=user1,
        ~admin,
      ),
    );

  let%AwaitThen _ = priceAndStateUpdate();

  let%AwaitThen _ =
    executeOnMarkets(
      initialMarkets,
      mintLongNextPriceWithSystemUpdate(
        ~amount=longMintAmount,
        ~marketIndex=_,
        ~paymentToken,
        ~longShort,
        ~user=user1,
        ~admin,
      ),
    );

  let%AwaitThen _ =
    executeOnMarkets(
      initialMarkets,
      shiftFromShortNextPriceWithSystemUpdate(
        ~amount=redeemShortAmount,
        ~marketIndex=_,
        ~longShort,
        ~user=user1,
        ~admin,
      ),
    );

  let%AwaitThen _ = priceAndStateUpdate();

  Js.log("Staking long position");
  let%AwaitThen _ =
    executeOnMarkets(
      initialMarkets,
      stakeSynthLong(
        ~amount=longStakeAmount,
        ~longShort,
        ~marketIndex=_,
        ~user=user1,
      ),
    );

  let%AwaitThen _ = priceAndStateUpdate();

  JsPromise.resolve();
};

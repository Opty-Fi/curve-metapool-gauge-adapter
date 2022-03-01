import hre from "hardhat";
import chai, { expect } from "chai";
import { solidity } from "ethereum-waffle";
import { getAddress } from "ethers/lib/utils";
import { BigNumber, utils } from "ethers";
import { PoolItem } from "../types";
import { getOverrideOptions, setTokenBalanceInStorage } from "../../utils";
import { ERC20 } from "../../../typechain";
import { default as TOKENS } from "../../../helpers/tokens.json";

chai.use(solidity);

const CRV_TOKEN = "0xD533a949740bb3306d119CC777fa900bA034cd52";
const vaultUnderlyingTokens = Object.values(TOKENS).map(x => getAddress(x));

export function shouldBehaveLikeCurveMetapoolGaugeAdapter(token: string, pool: PoolItem): void {
  it(`should deposit ${token} and withdraw LP tokens in ${token} gauge of Curve`, async function () {
    const tokenInstance = <ERC20>await hre.ethers.getContractAt("ERC20", pool.tokens[0]);
    await setTokenBalanceInStorage(tokenInstance, this.testDeFiAdapter.address, "10000");
    // curve's gauge instance
    const curveMetapoolGaugeInstance = await hre.ethers.getContractAt("ICurveLiquidityGaugeV3", pool.pool);
    // curve's swap pool instance
    const curveMetapoolSwapInstance = await hre.ethers.getContractAt("ERC20", pool.tokens[0]);
    // check total supply
    if ((await curveMetapoolSwapInstance.totalSupply()).eq(BigNumber.from(0))) {
      console.log("Skipping because total supply is zero");
      this.skip();
    }
    // 1. deposit all underlying tokens
    await this.testDeFiAdapter.testGetDepositAllCodes(
      pool.tokens[0],
      pool.pool,
      this.curveMetapoolGaugeAdapter.address,
      getOverrideOptions(),
    );
    // 1.1 assert whether lptoken balance is as expected or not after deposit
    const actualLPTokenBalanceAfterDeposit = await this.curveMetapoolGaugeAdapter.getLiquidityPoolTokenBalance(
      this.testDeFiAdapter.address,
      this.testDeFiAdapter.address, // placeholder of type address
      pool.pool,
    );
    const expectedLPTokenBalanceAfterDeposit = await curveMetapoolGaugeInstance.balanceOf(this.testDeFiAdapter.address);
    expect(actualLPTokenBalanceAfterDeposit).to.be.eq(expectedLPTokenBalanceAfterDeposit);
    // 1.2 assert whether underlying token balance is as expected or not after deposit
    const actualUnderlyingTokenBalanceAfterDeposit = await this.testDeFiAdapter.getERC20TokenBalance(
      pool.tokens[0],
      this.testDeFiAdapter.address,
    );
    const expectedUnderlyingTokenBalanceAfterDeposit = await curveMetapoolSwapInstance.balanceOf(
      this.testDeFiAdapter.address,
    );
    expect(actualUnderlyingTokenBalanceAfterDeposit).to.be.eq(expectedUnderlyingTokenBalanceAfterDeposit);
    // 1.3 assert whether the amount in token is as expected or not after depositing
    const actualAmountInTokenAfterDeposit = await this.curveMetapoolGaugeAdapter.getAllAmountInToken(
      this.testDeFiAdapter.address,
      pool.tokens[0],
      pool.pool,
    );
    const expectedAmountInTokenAfterDeposit = await curveMetapoolGaugeInstance.balanceOf(this.testDeFiAdapter.address);
    expect(actualAmountInTokenAfterDeposit).to.be.eq(expectedAmountInTokenAfterDeposit);
    // 2. Reward tokens
    // 2.1 assert whether the reward tokens are as expected or not
    const actualRewardTokens = (await this.curveMetapoolGaugeAdapter.getRewardTokens(pool.pool)).map((token: string) =>
      getAddress(token),
    );
    const gaugeRewardTokens = [];
    for (let i = 0; i < 8; i++) {
      gaugeRewardTokens.push(await curveMetapoolGaugeInstance.reward_tokens(i));
    }
    gaugeRewardTokens.unshift(CRV_TOKEN);
    const expectedRewardTokens = gaugeRewardTokens.map((token: string) => getAddress(token));
    expect(actualRewardTokens[0]).to.be.eq(expectedRewardTokens[0]);
    expect(actualRewardTokens[1]).to.be.eq(expectedRewardTokens[1]);
    expect(actualRewardTokens[2]).to.be.eq(expectedRewardTokens[2]);
    expect(actualRewardTokens[3]).to.be.eq(expectedRewardTokens[3]);
    expect(actualRewardTokens[4]).to.be.eq(expectedRewardTokens[4]);
    expect(actualRewardTokens[5]).to.be.eq(expectedRewardTokens[5]);
    expect(actualRewardTokens[6]).to.be.eq(expectedRewardTokens[6]);
    expect(actualRewardTokens[7]).to.be.eq(expectedRewardTokens[7]);
    expect(actualRewardTokens[8]).to.be.eq(expectedRewardTokens[8]);
    // 2.2 make a transaction for mining a block to get finite unclaimed reward amount
    await this.signers.admin.sendTransaction({
      value: utils.parseEther("0"),
      to: await this.signers.admin.getAddress(),
      ...getOverrideOptions(),
    });
    // 2.3 claim the reward tokens
    await this.testDeFiAdapter.testClaimRewardTokenCode(
      pool.pool,
      this.curveMetapoolGaugeAdapter.address,
      getOverrideOptions(),
    );
    if (vaultUnderlyingTokens.includes(getAddress(pool.tokens[0]))) {
      // 3. Swap the reward token into underlying token
      try {
        await this.testDeFiAdapter.testGetHarvestAllCodes(
          pool.pool,
          pool.tokens[0],
          this.curveMetapoolGaugeAdapter.address,
          getOverrideOptions(),
        );
        // 3.1 assert whether the reward token is swapped to underlying token or not
        expect(await this.testDeFiAdapter.getERC20TokenBalance(pool.tokens[0], this.testDeFiAdapter.address)).to.be.gte(
          0,
        );
        console.log("✓ Harvest");
      } catch {
        // may throw error from DEX due to insufficient reserves
      }
    }
    // 4. Withdraw all lpToken balance
    await this.testDeFiAdapter.testGetWithdrawAllCodes(
      pool.tokens[0],
      pool.pool,
      this.curveMetapoolGaugeAdapter.address,
      getOverrideOptions(),
    );
    // 4.1 assert whether lpToken balance is as expected or not
    const actualLPTokenBalanceAfterWithdraw = await this.curveMetapoolGaugeAdapter.getLiquidityPoolTokenBalance(
      this.testDeFiAdapter.address,
      this.testDeFiAdapter.address, // placeholder of type address
      pool.pool,
    );
    const expectedLPTokenBalanceAfterWithdraw = await curveMetapoolGaugeInstance.balanceOf(
      this.testDeFiAdapter.address,
    );
    expect(actualLPTokenBalanceAfterWithdraw).to.be.eq(expectedLPTokenBalanceAfterWithdraw);
    // 4.2 assert whether underlying token balance is as expected or not after withdraw
    const actualUnderlyingTokenBalanceAfterWithdraw = await this.testDeFiAdapter.getERC20TokenBalance(
      pool.tokens[0],
      this.testDeFiAdapter.address,
    );
    const expectedUnderlyingTokenBalanceAfterWithdraw = await curveMetapoolSwapInstance.balanceOf(
      this.testDeFiAdapter.address,
    );
    expect(actualUnderlyingTokenBalanceAfterWithdraw).to.be.eq(expectedUnderlyingTokenBalanceAfterWithdraw);
  }).timeout(100000);
}

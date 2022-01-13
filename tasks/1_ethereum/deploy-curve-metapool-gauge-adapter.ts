import { task } from "hardhat/config";
import { TaskArguments } from "hardhat/types";

import { CurveMetapoolGaugeAdapter, CurveMetapoolGaugeAdapter__factory } from "../../../typechain";

task("deploy-curve-metapool-gauge-adapter").setAction(async function (taskArguments: TaskArguments, { ethers }) {
  const curveMetapoolGaugeAdapterFactory: CurveMetapoolGaugeAdapter__factory = await ethers.getContractFactory(
    "CurveMetapoolGaugeAdapter",
  );
  const curveMetapoolGaugeAdapter: CurveMetapoolGaugeAdapter = <CurveMetapoolGaugeAdapter>(
    await curveMetapoolGaugeAdapterFactory.deploy()
  );
  await curveMetapoolGaugeAdapter.deployed();
  console.log("CurveMetapoolGaugeAdapter deployed to: ", curveMetapoolGaugeAdapter.address);
});

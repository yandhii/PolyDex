// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  const UToken = await hre.ethers.getContractFactory("UToken");
  const uToken = await UToken.deploy();
  const uTokenAddr = await uToken.getAddress();


  const PolyToken = await hre.ethers.getContractFactory("PolyToken");
  const polyToken = await PolyToken.deploy();
  const polyTokenAddr = await uToken.getAddress();


  const CurveLiquidityPool = await hre.ethers.getContractFactory("CurveLiquidityPool");
  const curveLiquidityPool = await CurveLiquidityPool.deploy(uToken, polyToken);
  const curveLiquidityPoolAddr = await curveLiquidityPool.getAddress();

  const CPLiquidityPool = await hre.ethers.getContractFactory("CPLiquidityPool");
  const cpLiquidityPool = await CPLiquidityPool.deploy(uToken, polyToken);
  const cpLiquidityPoolAddr = await cpLiquidityPool.getAddress();

  console.log(
    `===================Deploying===================\n
    UToken deployed to ${uTokenAddr}\n
    PolyToken deployed to ${polyTokenAddr}\n
    Constant Product Liquidity Pool deployed to ${cpLiquidityPoolAddr}\n
    Curve-like Liquidity Pool deployed to ${curveLiquidityPoolAddr}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

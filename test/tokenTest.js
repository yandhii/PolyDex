const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
describe("Token", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.


  async function deployTokenFixture() {

    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount] = await ethers.getSigners();

    const UToken = await ethers.getContractFactory("UToken");
    const PolyToken = await ethers.getContractFactory('PolyToken');

    const utoken = await UToken.deploy();
    const polytoken = await PolyToken.deploy();

    return { utoken, polytoken,  owner, otherAccount };
  }

  describe("Deployment", function () {

    it("PolyToken Should assign the total supply of tokens to the owner", async function () {
      const { utoken, polytoken,  owner } = await loadFixture(deployTokenFixture);
      const total = await polytoken.totalSupply();
      expect(total).to.equal(await polytoken.balanceOf(owner.address));
    });

    it("UToken Should assign the total supply of tokens to the owner", async function () {
      const { utoken, polytoken,  owner } = await loadFixture(deployTokenFixture);
      const total = await utoken.totalSupply();
      expect(total).to.equal(await utoken.balanceOf(owner.address));
    });

  });

  describe("Transaction", function () {

      it("PolyToken Should transfer tokens between accounts", async function () {
          const { utoken, polytoken, owner, otherAccount } = await loadFixture(deployTokenFixture);

          const ownerBalance = await polytoken.balanceOf(owner.address);

          await polytoken.transfer(otherAccount.address, 50);
          const addr1Balance = await polytoken.balanceOf(otherAccount.address);
          expect(addr1Balance).to.equal(50);

          const ownerNewBalance = await polytoken.balanceOf(owner.address);
          expect(ownerNewBalance).to.equal(ownerBalance - BigInt(50));
      });

      it("UToken Should transfer tokens between accounts", async function () {
        const { utoken, polytoken, owner, otherAccount } = await loadFixture(deployTokenFixture);

        const ownerBalance = await utoken.balanceOf(owner.address);

        await utoken.transfer(otherAccount.address, 50);
        const addr1Balance = await utoken.balanceOf(otherAccount.address);
        expect(addr1Balance).to.equal(50);

        const ownerNewBalance = await utoken.balanceOf(owner.address);
        expect(ownerNewBalance).to.equal(ownerBalance - BigInt(50));
    });

      it("PolyToken Should fail if sender doesn't have enough tokens", async function () {
        const { utoken, polytoken, owner, otherAccount } = await loadFixture(deployTokenFixture);

          // Transfer 10001 tokens from owner to otherAccount
          await expect(
           polytoken.transfer(otherAccount.address, ethers.parseEther('10001'))
          ).to.be.revertedWith("ERC20: transfer amount exceeds owner's balance");
      });    
      
      it("UToken Should fail if sender doesn't have enough tokens", async function () {
        const { utoken, polytoken, owner, otherAccount } = await loadFixture(deployTokenFixture);

        // Transfer 10001 tokens from owner to otherAccount
        await expect(
         utoken.transfer(otherAccount.address, ethers.parseEther('10001'))
        ).to.be.revertedWith("ERC20: transfer amount exceeds owner's balance");
    });  

    });

});
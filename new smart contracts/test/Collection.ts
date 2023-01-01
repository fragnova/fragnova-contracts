import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import {FragnovaBaseUri} from "../typechain-types";

describe("Collection", function () {

  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployCollectionFixture() {
    // Contracts are deployed using the first signer/account by default
    const [owner, alice] = await ethers.getSigners();

    const FragnovaBaseUri = await ethers.getContractFactory('FragnovaBaseUri');
    const baseUriProxy = await upgrades.deployProxy(FragnovaBaseUri, {'kind': 'uups'});
    await expect(baseUriProxy.setBaseUri("metadata.fragnova.com")).not.to.be.reverted;

    const Collection = await ethers.getContractFactory('Collection');
    const collection = await Collection.deploy();


    return { collection, baseUriProxy, owner, alice};
  }

  describe("Set Mint Price", function () {
    it("Should work", async function () {
      const {collection} = await loadFixture(deployCollectionFixture);
      await expect(collection.setMintPrice(ethers.utils.parseEther("777"))).not.to.be.reverted;
      expect(await collection.mintPrice()).is.equal(ethers.utils.parseEther("777"));
    });
    it("Should revert if caller is not owner", async function () {
      const {collection, alice} = await loadFixture(deployCollectionFixture);
      await expect(collection.connect(alice).setMintPrice(ethers.utils.parseEther("777"))).to.be.revertedWith(
          "Ownable: caller is not the owner"
      );
    });
  });

  describe("Set Royalty Info", function () {
    it("Should work", async function () {
      const {collection, owner} = await loadFixture(deployCollectionFixture);

      const receiver = owner.address;
      const feeInBips = 100;
      await expect(collection.setRoyaltyInfo(receiver, feeInBips)).not.to.be.reverted;

      expect(await collection.royaltyInfo(777, 111)).to.deep.equal([receiver, Math.floor(111 * feeInBips/10_000)]);
    });

    it("Should revert if caller is not owner", async function () {
      const {collection, alice} = await loadFixture(deployCollectionFixture);

      const receiver = alice.address;
      const feeInBips = 100;
      await expect(collection.connect(alice).setRoyaltyInfo(receiver, feeInBips)).to.be.revertedWith(
          "Ownable: caller is not the owner"
      );
    });
  });

});

import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";
import * as env from "hardhat";

describe("CollectionFactory", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployCollectionFactoryFixture() {
    // Contracts are deployed using the first signer/account by default
    const [owner, alice, bob] = await ethers.getSigners();

    const ProtoCollection = await ethers.getContractFactory('ProtoCollection');
    const protoCollection = await ProtoCollection.deploy();
    const InstanceCollection = await ethers.getContractFactory('InstanceCollection');
    const instanceCollection = await InstanceCollection.deploy();
    const CollectionFactory = await ethers.getContractFactory('CollectionFactory');
    const collectionFactory = await CollectionFactory.deploy(protoCollection.address, instanceCollection.address);

    return { collectionFactory, protoCollection, instanceCollection, owner, alice, bob };
  }

  describe("Deployment", function () {
    it("Should work", async function () {
      const { collectionFactory, protoCollection, instanceCollection } = await loadFixture(deployCollectionFactoryFixture);
      expect(await collectionFactory.protoCollectionImplementation()).to.equal(protoCollection.address);
      expect(await collectionFactory.instanceCollectionImplementation()).to.equal(instanceCollection.address);
    });
  });

  // describe("Add Authority", function () {
  //   it("Should work", async function () {
  //     const { collectionFactory, alice } = await loadFixture(deployCollectionFactoryFixture);
  //     await expect(collectionFactory.addAuthority(alice.address)).not.to.be.reverted;
  //     expect(await collectionFactory.getAuthorities()).to.equal([alice]);
  //   });
  //
  //   it("Should revert if caller is not owner", async function () {
  //     const { collectionFactory, alice } = await loadFixture(deployCollectionFactoryFixture);
  //     await expect(collectionFactory.connect(alice).addAuthority(alice.address)).to.be.revertedWith(
  //         "Ownable: caller is not the owner"
  //     );
  //   });
  // });

  describe("Attach Collection", function () {
    it("Should work", async function () {
      const { collectionFactory, alice, bob } = await loadFixture(deployCollectionFactoryFixture);

      await expect(collectionFactory.addAuthority(alice.address)).not.to.be.reverted;

      const collectionType = 0; // ProtoFragment
      const collectionMerkleRoot = "0x" + "77".repeat(32);
      const collectionName = ethers.utils.formatBytes32String("Dummy Name");
      const collectionSymbol = ethers.utils.formatBytes32String("DN");
      const signature = await alice.signMessage(
          ethers.utils.arrayify(
              ethers.utils.solidityKeccak256(
                  ["string", "bytes32", "uint256", "address", "uint256"],
                  ["Proto-Fragment", collectionMerkleRoot, env.network.config.chainId, bob.address, 0]
              )
          )
      );

      await expect(collectionFactory.connect(bob).attachCollection(
          collectionType,
          collectionMerkleRoot,
          collectionName,
          collectionSymbol,
          signature
      )).to.emit(collectionFactory, "CollectionCreated");

    });

    it("Should revert if the signature is invalid", async function () {
      const { collectionFactory, alice, bob } = await loadFixture(deployCollectionFactoryFixture);

      await expect(collectionFactory.addAuthority(alice.address)).not.to.be.reverted;

      const collectionType = 0; // ProtoFragment
      const collectionMerkleRoot = "0x" + "77".repeat(32);
      const collectionName = ethers.utils.formatBytes32String("Dummy Name");
      const collectionSymbol = ethers.utils.formatBytes32String("DN");
      const signature = "0xbbf4029d3724f75f1a5ec385aa696558c1e62d34af59d5c6494346f4602129f64cbc450cb006ad13ac58b0600391e3a599d070974f8873f0b720b90a22a1e1b21c"; // random signature

      await expect(collectionFactory.connect(bob).attachCollection(
          collectionType,
          collectionMerkleRoot,
          collectionName,
          collectionSymbol,
          signature
      )).to.be.revertedWith(
          "Invalid Signature"
      );

    });

  });
});

import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import * as env from "hardhat";
import {Contract} from "ethers";
import {MerkleTree} from "merkletreejs";
import {CollectionFactory, FragnovaBaseUri} from "../typechain-types";

describe("InstanceCollection", function () {

  async function deployBaseUriProxy(): Promise<FragnovaBaseUri> {
    const FragnovaBaseUri = await ethers.getContractFactory('FragnovaBaseUri');
    const baseUriProxy = await upgrades.deployProxy(FragnovaBaseUri, {'kind': 'uups'});

    return baseUriProxy;
  }

  async function deployCollectionFactory(): Promise<CollectionFactory> {
    const ProtoCollection = await ethers.getContractFactory('ProtoCollection');
    const protoCollection = await ProtoCollection.deploy();
    const InstanceCollection = await ethers.getContractFactory('InstanceCollection');
    const instanceCollection = await InstanceCollection.deploy();
    const CollectionFactory = await ethers.getContractFactory('CollectionFactory');
    const collectionFactory = await CollectionFactory.deploy(protoCollection.address, instanceCollection.address);

    return collectionFactory;
  }

  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployInstanceCollectionFixture() {

    // Contracts are deployed using the first signer/account by default
    const [owner, alice] = await ethers.getSigners();

    const collectionFactory = await deployCollectionFactory();
    const baseUriProxy = await deployBaseUriProxy();

    await expect(collectionFactory.updateAuthorities([alice.address], true)).not.to.be.reverted;
    await expect(baseUriProxy.setBaseUri("metadata.fragnova.com")).not.to.be.reverted;

    const instances = [["0x" + "11".repeat(16), 1, 1], ["0x" + "22".repeat(16), 2, 1], ["0x" + "33".repeat(16), 3, 1]];
    const [instance1] = instances;
    const collectionMerkleTree = new MerkleTree(instances.map(i => ethers.utils.arrayify( ethers.utils.solidityKeccak256(["bytes16", "uint64", "uint64"], [i[0], i[1], i[2]]))), ethers.utils.keccak256, {sortPairs: true, sortLeaves: true});
    const collectionType = 1; // Fragment Instance
    const collectionMerkleRoot = '0x' + collectionMerkleTree.getRoot().toString('hex');
    let [collectionName, collectionSymbol] = [ethers.utils.formatBytes32String("Dummy Name"), ethers.utils.formatBytes32String("DN")];
    const shouldRegisterWithOpenseaFilterRegistry = false;
    const signature = alice.signMessage(
        ethers.utils.arrayify(
            ethers.utils.solidityKeccak256(
                ["uint8", "bytes32", "uint256", "address", "uint64"],
                [collectionType, collectionMerkleRoot, env.network.config.chainId, owner.address, 1]
            )
        )
    );
    const tx = await collectionFactory.attachCollection(collectionType, collectionMerkleRoot, collectionName, collectionSymbol, shouldRegisterWithOpenseaFilterRegistry, signature);
    const { events } = await tx.wait();
    const instanceCollectionAddress = events.find(e => e.event === "CollectionCreated").args[0];

    const InstanceCollection = await ethers.getContractFactory('InstanceCollection');
    const instanceCollection = InstanceCollection.attach(instanceCollectionAddress);

    await expect(instanceCollection.setBaseUriProxy(baseUriProxy.address)).not.to.be.reverted;

    collectionName = ethers.utils.parseBytes32String(collectionName);
    collectionSymbol = ethers.utils.parseBytes32String(collectionSymbol);
    return { instanceCollection, baseUriProxy, collectionMerkleRoot, collectionName, collectionSymbol, instances, instance1, collectionMerkleTree, owner, alice };
  }

  describe("Deployment", function () {
    it("Should work", async function () {
      const {instanceCollection, owner, collectionMerkleRoot, collectionName, collectionSymbol} = await loadFixture(deployInstanceCollectionFixture);
      expect(await instanceCollection.merkleRoot()).to.equal(collectionMerkleRoot);
      expect(await instanceCollection.owner()).to.equal(owner.address);
      expect((await instanceCollection.name()) === collectionName); // We are doing `===` instead of `to.equal()` because `to.equal()` also looks at the null bytes ("\u0000") at the end of the returned string
      expect((await instanceCollection.symbol()) === collectionSymbol); // We are doing `===` instead of `to.equal()` because `to.equal()` also looks at the null bytes ("\u0000") at the end of the returned string
    });
  });

  describe("Mint", function () {
    it("Should work", async function () {
      const { instanceCollection, instance1, collectionMerkleTree} = await loadFixture(deployInstanceCollectionFixture);
      const [definitionHash, editionId, copyId] = instance1;
      const proof = collectionMerkleTree.getHexProof(ethers.utils.solidityKeccak256(["bytes16", "uint64", "uint64"], [definitionHash, editionId, copyId]));
      await expect(instanceCollection.safeMint(proof, definitionHash, editionId, {value: instanceCollection.mintPrice()})).not.to.be.reverted;
    });
    it("Should revert if Fragment Instance does not exist", async function () {
      const { instanceCollection, instance1, collectionMerkleTree} = await loadFixture(deployInstanceCollectionFixture);
      const [definitionHash, editionId, copyId] = instance1;
      const proof = collectionMerkleTree.getHexProof(ethers.utils.solidityKeccak256(["bytes16", "uint64", "uint64"], [definitionHash, editionId, copyId]));

      const [fakeInstance, fakeEditionId] = ["0x" + "00".repeat(16), 1];

      await expect(instanceCollection.safeMint(proof, fakeInstance, fakeEditionId, {value: instanceCollection.mintPrice()})).to.be.revertedWith(
          "Fragment Instance is not a part of the Collection"
      );

    });
    it("Should revert if the msg.value is not smaller than the mint price", async function () {
      const { instanceCollection, instance1, collectionMerkleTree} = await loadFixture(deployInstanceCollectionFixture);
      const [definitionHash, editionId, copyId] = instance1;

      await expect(instanceCollection.setMintPrice(ethers.utils.parseEther("777"))).not.to.be.reverted;

      const proof = collectionMerkleTree.getHexProof(ethers.utils.solidityKeccak256(["bytes16", "uint64", "uint64"], [definitionHash, editionId, copyId]));
      await expect(instanceCollection.safeMint(proof, definitionHash, editionId, {value: ethers.utils.parseEther("776")})).to.be.revertedWith(
          "Mint price not paid"
      );
    });
    it("Should revert if Fragment Instance was already minted", async function () {
      const { instanceCollection, instance1, collectionMerkleTree} = await loadFixture(deployInstanceCollectionFixture);
      const [definitionHash, editionId] = instance1;
      const proof = collectionMerkleTree.getHexProof(ethers.utils.solidityKeccak256(["bytes16", "uint64", "uint64"], [instance1[0], instance1[1], instance1[2]]));
      await expect(instanceCollection.safeMint(proof, definitionHash, editionId, {value: instanceCollection.mintPrice()})).not.to.be.reverted;
      await expect(instanceCollection.safeMint(proof, definitionHash, editionId, {value: instanceCollection.mintPrice()})).to.be.revertedWith(
          "Fragment Instance was already minted"
      );
    });
  });

  describe("Token ID of Instance", function () {
    it("Should work", async function () {
      const { instanceCollection, instance1, collectionMerkleTree} = await loadFixture(deployInstanceCollectionFixture);
      const [definitionHash, editionId, copyId] = instance1;
      const proof = collectionMerkleTree.getHexProof(ethers.utils.solidityKeccak256(["bytes16", "uint64", "uint64"], [definitionHash, editionId, copyId]));
      await expect(instanceCollection.safeMint(proof, definitionHash, editionId, {value: instanceCollection.mintPrice()})).not.to.be.reverted;

      expect(await instanceCollection.tokenIdOfInstance(definitionHash, editionId)).to.equal(0);
    });
    it("Should revert if token ID does not exist", async function () {
      const { instanceCollection, instance1} = await loadFixture(deployInstanceCollectionFixture);
      const [definitionHash, editionId, copyId] = instance1;
      await expect(instanceCollection.tokenIdOfInstance(definitionHash, editionId)).to.be.revertedWith(
          "No Token ID found"
      );
    });
  });


  describe("Token URI", function () {
    it("Should work", async function() {
      const { instanceCollection, baseUriProxy, instance1, collectionMerkleTree} = await loadFixture(deployInstanceCollectionFixture);
      const [definitionHash, editionId, copyId] = instance1;
      const proof = collectionMerkleTree.getHexProof(ethers.utils.solidityKeccak256(["bytes16", "uint64", "uint64"], [definitionHash, editionId, copyId]));
      await expect(instanceCollection.safeMint(proof, definitionHash, editionId, {value: instanceCollection.mintPrice()})).not.to.be.reverted;

      expect(await instanceCollection.tokenURI(0)).to.equal((await baseUriProxy.baseUri()) + "/f/" + definitionHash + "-" + editionId + "-" + copyId);
    });
    it("Should revert if token ID does not exist", async function () {
      const {instanceCollection} = await loadFixture(deployInstanceCollectionFixture);
      await expect(instanceCollection.tokenURI(0)).to.be.revertedWithCustomError(
          instanceCollection, 'URIQueryForNonexistentToken'
      );
    });
  });

});

import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import * as env from "hardhat";
import {Contract} from "ethers";
import {MerkleTree} from "merkletreejs";
import {CollectionFactory, FragnovaBaseUri} from "../typechain-types";

describe("ProtoCollection", function () {

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
  async function deployProtoCollectionFixture() {

    // Contracts are deployed using the first signer/account by default
    const [owner, alice] = await ethers.getSigners();

    const collectionFactory = await deployCollectionFactory();
    const baseUriProxy = await deployBaseUriProxy();

    await expect(collectionFactory.updateAuthorities([alice.address], true)).not.to.be.reverted;
    await expect(baseUriProxy.setBaseUri("metadata.fragnova.com")).not.to.be.reverted;

    const protos = ["0x" + "11".repeat(32), "0x" + "22".repeat(32), "0x" + "33".repeat(32)];
    const [proto1] = protos;
    const collectionMerkleTree = new MerkleTree(protos.map(p => ethers.utils.arrayify(ethers.utils.solidityKeccak256(["bytes32"], [p]))), ethers.utils.keccak256, {sortPairs: true});
    const collectionType = 0; // Proto-Fragment
    const collectionMerkleRoot = '0x' + collectionMerkleTree.getRoot().toString('hex');
    let [collectionName, collectionSymbol] = [ethers.utils.formatBytes32String("Dummy Name"), ethers.utils.formatBytes32String("DN")];
    const shouldRegisterWithOpenseaFilterRegistry = false;
    const signature = alice.signMessage(
        ethers.utils.arrayify(
            ethers.utils.solidityKeccak256(
                ["string", "bytes32", "uint256", "address", "uint64"],
                ["Proto-Fragment", collectionMerkleRoot, env.network.config.chainId, owner.address, 1]
            )
        )
    );
    const tx = await collectionFactory.attachCollection(collectionType, collectionMerkleRoot, collectionName, collectionSymbol, shouldRegisterWithOpenseaFilterRegistry, signature);
    const { events } = await tx.wait();
    const protoCollectionAddress = events.find(e => e.event === "CollectionCreated").args[0];

    const ProtoCollection = await ethers.getContractFactory('ProtoCollection');
    const protoCollection = ProtoCollection.attach(protoCollectionAddress);

    await expect(protoCollection.setBaseUriProxy(baseUriProxy.address)).not.to.be.reverted;

    collectionName = ethers.utils.parseBytes32String(collectionName);
    collectionSymbol = ethers.utils.parseBytes32String(collectionSymbol);
    return { protoCollection, baseUriProxy, collectionMerkleRoot, collectionName, collectionSymbol, protos, proto1, collectionMerkleTree, owner, alice };
  }

  describe("Deployment", function () {
    it("Should work", async function () {
      const {protoCollection, owner, collectionMerkleRoot, collectionName, collectionSymbol} = await loadFixture(deployProtoCollectionFixture);
      expect(await protoCollection.merkleRoot()).to.equal(collectionMerkleRoot);
      expect(await protoCollection.owner()).to.equal(owner.address);
      expect((await protoCollection.name()) === collectionName); // We are doing `===` instead of `to.equal()` because `to.equal()` also looks at the null bytes ("\u0000") at the end of the returned string
      expect((await protoCollection.symbol()) === collectionSymbol); // We are doing `===` instead of `to.equal()` because `to.equal()` also looks at the null bytes ("\u0000") at the end of the returned string
    });
  });

  describe("Mint", function () {
    it("Should work", async function () {
      const { protoCollection, proto1, collectionMerkleTree} = await loadFixture(deployProtoCollectionFixture);
      const proof = collectionMerkleTree.getHexProof(ethers.utils.solidityKeccak256(["bytes32"], [proto1]));
      await expect(protoCollection.safeMint(proof, proto1, {value: protoCollection.mintPrice()})).not.to.be.reverted;
    });
    it("Should revert if Proto-Fragment does not exist", async function () {
      const { protoCollection, proto1, collectionMerkleTree} = await loadFixture(deployProtoCollectionFixture);
      const proof = collectionMerkleTree.getHexProof(ethers.utils.solidityKeccak256(["bytes32"], [proto1]));

      const fakeProto = "0x" + "00".repeat(32);

      await expect(protoCollection.safeMint(proof, fakeProto, {value: protoCollection.mintPrice()})).to.be.revertedWith(
          "Proto-Fragment is not a part of the Collection"
      );

    });
    it("Should revert if the msg.value is not smaller than the mint price", async function () {
      const { protoCollection, proto1, collectionMerkleTree} = await loadFixture(deployProtoCollectionFixture);

      await expect(protoCollection.setMintPrice(ethers.utils.parseEther("777"))).not.to.be.reverted;

      const proof = collectionMerkleTree.getHexProof(ethers.utils.solidityKeccak256(["bytes32"], [proto1]));
      await expect(protoCollection.safeMint(proof, proto1, {value: ethers.utils.parseEther("776")})).to.be.revertedWith(
          "Mint price not paid"
      );
    });
    it("Should revert if Proto-Fragment was already minted", async function () {
      const { protoCollection, proto1, collectionMerkleTree} = await loadFixture(deployProtoCollectionFixture);
      const proof = collectionMerkleTree.getHexProof(ethers.utils.solidityKeccak256(["bytes32"], [proto1]));
      await expect(protoCollection.safeMint(proof, proto1, {value: protoCollection.mintPrice()})).not.to.be.reverted;
      await expect(protoCollection.safeMint(proof, proto1, {value: protoCollection.mintPrice()})).to.be.revertedWith(
          "Proto-Fragment was already minted"
      );
    });
  });

  describe("Token ID of Proto", function () {
    it("Should work", async function () {
      const { protoCollection, proto1, collectionMerkleTree} = await loadFixture(deployProtoCollectionFixture);
      const proof = collectionMerkleTree.getHexProof(ethers.utils.solidityKeccak256(["bytes32"], [proto1]));
      await expect(protoCollection.safeMint(proof, proto1, {value: protoCollection.mintPrice()})).not.to.be.reverted;

      expect(await protoCollection.tokenIdOfProto(proto1)).to.equal(0);
    });
    it("Should revert if token ID does not exist", async function () {
      const { protoCollection, proto1} = await loadFixture(deployProtoCollectionFixture);
      await expect(protoCollection.tokenIdOfProto(proto1)).to.be.revertedWith(
          "No Token ID found"
      );
    });

  });

  describe("Token URI", function () {
    it("Should work", async function() {
      const { protoCollection, baseUriProxy, proto1, collectionMerkleTree} = await loadFixture(deployProtoCollectionFixture);
      const proof = collectionMerkleTree.getHexProof(ethers.utils.solidityKeccak256(["bytes32"], [proto1]));
      await expect(protoCollection.safeMint(proof, proto1, {value: protoCollection.mintPrice()})).not.to.be.reverted;

      expect(await protoCollection.tokenURI(0)).to.equal((await baseUriProxy.baseUri()) + "/p/" + proto1);

    });
    it("Should revert if token ID does not exist", async function () {
      const {protoCollection} = await loadFixture(deployProtoCollectionFixture);
      await expect(protoCollection.tokenURI(0)).to.be.revertedWithCustomError(
          protoCollection, 'URIQueryForNonexistentToken'
      );
    });
  });

});

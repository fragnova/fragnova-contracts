import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";
import * as env from "hardhat";

// For the end-to-end test
import { ApiPromise } from '@polkadot/api';
import { Vec, U8aFixed } from '@polkadot/types-codec';
import { AddressOrPair } from '@polkadot/api/types';
import { blake2AsU8a } from "@polkadot/util-crypto";
import { Keyring } from "@polkadot/keyring";
import { createFragnovaApi, Protos, Fragments } from "@fragnova/sdk";
import {MerkleTree} from "merkletreejs";


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

  describe("Update Authority", function () {
    describe("Add Authorities", function () {
      it("Should work", async function () {
        const { collectionFactory, alice, bob } = await loadFixture(deployCollectionFactoryFixture);
        await expect(collectionFactory.updateAuthorities([alice.address, bob.address], true)).not.to.be.reverted;
        expect(await collectionFactory.getAuthorities()).to.deep.equal([alice.address, bob.address]);
      });

      it("Should revert if caller is not owner", async function () {
        const { collectionFactory, alice, bob } = await loadFixture(deployCollectionFactoryFixture);
        await expect(collectionFactory.connect(alice).updateAuthorities([alice.address, bob.address], true)).to.be.revertedWith(
            "Ownable: caller is not the owner"
        );
      });
    });

    describe("Remove Authorities", function () {
      it("Should work", async function () {
        const { collectionFactory, alice, bob } = await loadFixture(deployCollectionFactoryFixture);
        await expect(collectionFactory.updateAuthorities([alice.address, bob.address], true)).not.to.be.reverted;

        await expect(collectionFactory.updateAuthorities([alice.address], false)).not.to.be.reverted;
        expect(await collectionFactory.getAuthorities()).to.deep.equal([bob.address]);
      });

      it("Should revert if caller is not owner", async function () {
        const { collectionFactory, alice, bob } = await loadFixture(deployCollectionFactoryFixture);
        await expect(collectionFactory.updateAuthorities([alice.address, bob.address], true)).not.to.be.reverted;

        await expect(collectionFactory.connect(alice).updateAuthorities([alice.address], false)).to.be.revertedWith(
            "Ownable: caller is not the owner"
        );
      });
    });
  });

  describe("Attach Collection", function () {
    it("Should work", async function () {
      const { collectionFactory, alice, bob } = await loadFixture(deployCollectionFactoryFixture);

      await expect(collectionFactory.updateAuthorities([alice.address], true)).not.to.be.reverted;

      const collectionType = 0; // ProtoFragment
      const collectionMerkleRoot = "0x" + "77".repeat(32);
      const collectionName = ethers.utils.formatBytes32String("Dummy Name");
      const collectionSymbol = ethers.utils.formatBytes32String("DN");
      const shouldRegisterWithOpenseaFilterRegistry = false;
      const signature = await alice.signMessage(
          ethers.utils.arrayify(
              ethers.utils.solidityKeccak256(
                  ["string", "bytes32", "uint256", "address", "uint64"],
                  ["Proto-Fragment", collectionMerkleRoot, env.network.config.chainId, bob.address, 1]
              )
          )
      );

      await expect(collectionFactory.connect(bob).attachCollection(
          collectionType,
          collectionMerkleRoot,
          collectionName,
          collectionSymbol,
          shouldRegisterWithOpenseaFilterRegistry,
          signature,
      )).to.emit(collectionFactory, "CollectionCreated");

    });

    it("Should revert if the signature is invalid", async function () {
      const { collectionFactory, alice, bob } = await loadFixture(deployCollectionFactoryFixture);

      await expect(collectionFactory.updateAuthorities([alice.address], true)).not.to.be.reverted;

      const collectionType = 0; // ProtoFragment
      const collectionMerkleRoot = "0x" + "77".repeat(32);
      const collectionName = ethers.utils.formatBytes32String("Dummy Name");
      const collectionSymbol = ethers.utils.formatBytes32String("DN");
      const shouldRegisterWithOpenseaFilterRegistry = false;
      const signature = "0xbbf4029d3724f75f1a5ec385aa696558c1e62d34af59d5c6494346f4602129f64cbc450cb006ad13ac58b0600391e3a599d070974f8873f0b720b90a22a1e1b21c"; // random signature

      await expect(collectionFactory.connect(bob).attachCollection(
          collectionType,
          collectionMerkleRoot,
          collectionName,
          collectionSymbol,
          shouldRegisterWithOpenseaFilterRegistry,
          signature
      )).to.be.revertedWith(
          "Invalid Signature"
      );

    });

  });

  describe("Detach Collection from Clamor and Attach it to Ethereum", function () {

    let api: ApiPromise;
    let clamorAlice: AddressOrPair;
    let protoHash: Uint8Array;
    let protoHash2: Uint8Array;
    let definitionHash: Uint8Array;
    let instanceIds: Array<[Uint8Array, number, number]>


    async function sleep(ms: number) {
      return new Promise(r => setTimeout(r, ms));
    }

    before(async function () {
      // the `beforeAll` hook should timeout after 20,000 ms (the default is 2000 ms). We do this because it takes time to connect to the local node, since the node was just launched immediately prior.
      this.timeout(200_000);

      api = await createFragnovaApi("ws://127.0.0.1:9944");

      const keyring = new Keyring({type: 'sr25519', ss58Format: 93});
      clamorAlice = keyring.addFromUri('//Alice');

      await api.rpc.author.insertKey("deta", "//Alice", ethers.utils.hexlify(new Keyring({type: 'ed25519'}).addFromUri("//Alice").publicKey));

      const protos = new Protos(api);
      await protos.upload(clamorAlice, {
        references: [],
        category: {text: 'plain'},
        tags: [],
        linkedAsset: null,
        license: null,
        cluster: null,
        data: "Proto-Indo-European",
      });
      protoHash = blake2AsU8a("Proto-Indo-European");
      await sleep(6000);
      await protos.upload(clamorAlice, {
        references: [],
        category: {text: 'plain'},
        tags: [],
        linkedAsset: null,
        license: null,
        cluster: null,
        data: "Proto-Austronesian",
      });
      protoHash2 = blake2AsU8a("Proto-Austronesian");
      await sleep(6000);

      const fragments = new Fragments(api);
      await fragments.create(clamorAlice, {
        protoHash: protoHash,
        metadata: {name: "Le nom", currency: "Native"},
        permissions: new Uint8Array(2),
        unique: null,
        maxSupply: null
      });
      definitionHash = blake2AsU8a(new Uint8Array([...protoHash, ...api.createType("FragmentMetadata", {name: "Le nom", currency: null}).toU8a()]), 128);
      await sleep(6000);
      await fragments.mint(clamorAlice, {
        definitionHash: definitionHash,
        options: {Quantity: 77},
        stackAmount: null,
      });
      instanceIds = new Array(77).fill(0).map((value, index) => [definitionHash, index + 1, 1] );
      await sleep(6000);
    });

    describe("Proto-Fragment Collection", function () {
      it("Should work", async function () {
        // the `it` hook should timeout after 20,000 ms (the default is 2000 ms). We do this because it takes time to get the nonce and then call `accounts.link()`
        this.timeout(200_000);

        const { collectionFactory, alice } = await loadFixture(deployCollectionFactoryFixture);

        // Update Ethereum Authorities in `CollectionFactory`
        const ecdsaEthereumAuthorities = (await api.query.detach.ethereumAuthorities()).toJSON() as string[];
        const ethereumAuthorities = ecdsaEthereumAuthorities.map(ecdsaPublicKey => ethers.utils.computeAddress(ecdsaPublicKey));
        await expect(collectionFactory.updateAuthorities(ethereumAuthorities, true)).not.to.be.reverted;

        // Detach Proto-Fragments from Clamor
        let targetChain: string;
        switch (env.network.config.chainId) {
          case 1:
            targetChain = 'EthereumMainnet';
            break;
          case 4:
            targetChain = 'EthereumRinkeby';
            break;
          case 5:
            targetChain = 'EthereumGoerli';
            break;
          default:
            throw new Error("What is real never ceases to be. The unreal never is.");
        }
        const protoHashes = [protoHash, protoHash2];
        const txHash = await api.tx.protos.detach(
            protoHashes as Vec<U8aFixed>,
            targetChain,
            alice.address
        ).signAndSend(clamorAlice);

        const [merkleRoot, remoteSignature, collectionType, collection] = await new Promise((resolve, reject) => {
          // Subscribe to system events via storage.
          api.query.system.events((events) => {
            // Loop through the Vec<EventRecord>
            events.forEach((record) => {
              // Extract the phase, event and the event types
              const { event, phase } = record;

              if (event.section === "detach" && event.method === "CollectionDetached") {
                const [merkleRoot, remoteSignature, collectionType, collection] = event.data;
                if (new TextDecoder("utf-8").decode(collectionType) === "Proto-Fragment") {
                  resolve(event.data);
                }
              }

            });
          });
        });

        await expect(collectionFactory.connect(alice).attachCollection(
            0, // ProtoFragment
            ethers.utils.hexlify(merkleRoot),
            ethers.utils.formatBytes32String("Dummy Name"),
            ethers.utils.formatBytes32String("DN"),
            false,
            ethers.utils.hexlify(remoteSignature),
        )).to.emit(collectionFactory, "CollectionCreated").withArgs((address: string) => this.address = address);

        const ProtoCollection = await ethers.getContractFactory('ProtoCollection');
        const protoCollection = ProtoCollection.attach(this.address);

        const collectionMerkleTree = new MerkleTree(protoHashes.map(p => ethers.utils.arrayify(ethers.utils.solidityKeccak256(["bytes32"], [p]))), ethers.utils.keccak256, {sortPairs: true});

        expect(await protoCollection.merkleRoot()).to.equal(collectionMerkleTree.getHexRoot());

        for (const pH of protoHashes) {
          const proof = collectionMerkleTree.getHexProof(ethers.utils.solidityKeccak256(["bytes32"], [pH]));
          await expect(protoCollection.safeMint(proof, pH, {value: protoCollection.mintPrice()})).not.to.be.reverted;
        }

      });

    });

    describe("Fragment Instance Collection", function () {
      it("Should work", async function () {
        // the `it` hook should timeout after 20,000 ms (the default is 2000 ms). We do this because it takes time to get the nonce and then call `accounts.link()`
        this.timeout(200_000);

        // We use `bob` here instead of `alice` because `alice`'s nonce may have been incremented (in Clamor) when the `describe("Proto-Fragment Collection")` test above was run
        const { collectionFactory, bob } = await loadFixture(deployCollectionFactoryFixture);

        // Update Ethereum Authorities in `CollectionFactory`
        const ecdsaEthereumAuthorities = (await api.query.detach.ethereumAuthorities()).toJSON() as string[];
        const ethereumAuthorities = ecdsaEthereumAuthorities.map(ecdsaPublicKey => ethers.utils.computeAddress(ecdsaPublicKey));
        await expect(collectionFactory.updateAuthorities(ethereumAuthorities, true)).not.to.be.reverted;

        // Detach Fragment Instances from Clamor
        let targetChain: string;
        switch (env.network.config.chainId) {
          case 1:
            targetChain = 'EthereumMainnet';
            break;
          case 4:
            targetChain = 'EthereumRinkeby';
            break;
          case 5:
            targetChain = 'EthereumGoerli';
            break;
          default:
            throw new Error("What is real never ceases to be. The unreal never is.");
        }
        const editionIds: Array<number> = instanceIds.map(([_, edition_Id], index) => edition_Id);
        const txHash = api.tx.fragments.detach(
            definitionHash,
            editionIds,
            targetChain,
            bob.address
        ).signAndSend(clamorAlice);

        const [merkleRoot, remoteSignature, collectionType, collection] = await new Promise((resolve, reject) => {
          // Subscribe to system events via storage.
          api.query.system.events((events) => {
            // Loop through the Vec<EventRecord>
            events.forEach((record) => {
              // Extract the phase, event and the event types
              const { event, phase } = record;
              if (event.section === "detach" && event.method === "CollectionDetached") {
                const [merkleRoot, remoteSignature, collectionType, collection] = event.data;
                if (new TextDecoder("utf-8").decode(collectionType) === "Fragment Instance") {
                  resolve(event.data);
                }
              }
            });
          });
        });

        await expect(collectionFactory.connect(bob).attachCollection(
            1, // Fragment Instance
            ethers.utils.hexlify(merkleRoot),
            ethers.utils.formatBytes32String("Dummy Name"),
            ethers.utils.formatBytes32String("DN"),
            false,
            ethers.utils.hexlify(remoteSignature),
        )).to.emit(collectionFactory, "CollectionCreated").withArgs((address: string) => this.address = address);

        const InstanceCollection = await ethers.getContractFactory('InstanceCollection');
        const instanceCollection = InstanceCollection.attach(this.address);

        const collectionMerkleTree = new MerkleTree(instanceIds.map(i => ethers.utils.arrayify( ethers.utils.solidityKeccak256(["bytes16", "uint64", "uint64"], [ethers.utils.hexlify(i[0]), i[1], i[2]]))), ethers.utils.keccak256, {sortPairs: true});

        expect(await instanceCollection.merkleRoot()).to.equal(collectionMerkleTree.getHexRoot());

        for (const [definitionHash, editionId, copyId] of instanceIds) {
          const proof = collectionMerkleTree.getHexProof(ethers.utils.solidityKeccak256(["bytes16", "uint64", "uint64"], [ethers.utils.hexlify(definitionHash), editionId, copyId]));
          await expect(instanceCollection.safeMint(proof, ethers.utils.hexlify(definitionHash), editionId, {value: instanceCollection.mintPrice()})).not.to.be.reverted;
        }

      });
    });

  });

});

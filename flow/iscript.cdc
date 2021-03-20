import Crypto
import HastenUtility from "./utility.cdc"

pub contract IHastenScript {
  pub resource interface ScriptView {
    pub let hashId: UInt256
    pub let metadata: String
    pub fun getCode(): [UInt8]
    pub fun getEnvironment(): [UInt8]
  }

  pub resource Script : ScriptView {
    // The unique hash of the code also our index id
    pub let hashId: UInt256

    // The script json metadata
    pub let metadata: String

    // The binary compressed code
    access(self) let code: [UInt8]

    pub fun getCode(): [UInt8] {
      return self.code
    }

    // The binary compressed environment
    // script owners can change this
    access(self) var environment: [UInt8]

    pub fun getEnvironment(): [UInt8] {
      return self.environment
    }

    pub fun setEnvironment(environment: [UInt8]) {
      self.environment = environment
    }

    // Initialize both fields in the init function
    init(hashId: UInt256, metadata: String, code: [UInt8], environment: [UInt8]) {
      self.hashId = hashId
      self.metadata = metadata
      self.code = code
      self.environment = environment
    }

    destroy() {
      panic("Scripts can't be destroyed!")
    }
  }

  pub fun createScript(metadata: String, code: [UInt8], environment: [UInt8]): @Script {
    let hashId = HastenUtility.sha3_160(bytes: code)
    return <- create Script(hashId: hashId, metadata: metadata, code: code, environment: environment)
  }

  // We define this interface purely as a way to allow users
  // to create public, restricted references to their Script Collection.
  // They would use this to only expose the deposit, getIDs,
  // and idExists fields in their Collection
  pub resource interface ScriptReceiver {
    pub fun deposit(token: @Script)
    pub fun getIDs(): [UInt256]
    pub fun idExists(id: UInt256): Bool
    pub fun view(id: UInt256): &{ScriptView}?;
  }
}
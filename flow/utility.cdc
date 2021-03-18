import Crypto

pub contract HastenUtility {
  pub fun sha3_160(bytes: [UInt8]): UInt256 {
    var hbytes = Crypto.hash(bytes, algorithm: Crypto.SHA3_256)
    var uhash = 0 as UInt256
    // inspired by ethereum addresses
    //uhash = uhash | UInt256(Int(hbytes[0]) << 248)
    //uhash = uhash | UInt256(Int(hbytes[1]) << 240)
    //uhash = uhash | UInt256(Int(hbytes[2]) << 232)
    //uhash = uhash | UInt256(Int(hbytes[3]) << 224)
    //uhash = uhash | UInt256(Int(hbytes[4]) << 216)
    //uhash = uhash | UInt256(Int(hbytes[5]) << 208)
    //uhash = uhash | UInt256(Int(hbytes[6]) << 200)
    //uhash = uhash | UInt256(Int(hbytes[7]) << 192)
    //uhash = uhash | UInt256(Int(hbytes[8]) << 184)
    //uhash = uhash | UInt256(Int(hbytes[9]) << 176)
    //uhash = uhash | UInt256(Int(hbytes[10]) << 168)
    //uhash = uhash | UInt256(Int(hbytes[11]) << 160)
    uhash = uhash | UInt256(Int(hbytes[12]) << 152)
    uhash = uhash | UInt256(Int(hbytes[13]) << 144)
    uhash = uhash | UInt256(Int(hbytes[14]) << 136)
    uhash = uhash | UInt256(Int(hbytes[15]) << 128)
    uhash = uhash | UInt256(Int(hbytes[16]) << 120)
    uhash = uhash | UInt256(Int(hbytes[17]) << 112)
    uhash = uhash | UInt256(Int(hbytes[18]) << 104)
    uhash = uhash | UInt256(Int(hbytes[19]) << 96)
    uhash = uhash | UInt256(Int(hbytes[20]) << 88)
    uhash = uhash | UInt256(Int(hbytes[21]) << 80)
    uhash = uhash | UInt256(Int(hbytes[22]) << 72)
    uhash = uhash | UInt256(Int(hbytes[23]) << 64)
    uhash = uhash | UInt256(Int(hbytes[24]) << 56)
    uhash = uhash | UInt256(Int(hbytes[25]) << 48)
    uhash = uhash | UInt256(Int(hbytes[26]) << 40)
    uhash = uhash | UInt256(Int(hbytes[27]) << 32)
    uhash = uhash | UInt256(Int(hbytes[28]) << 24)
    uhash = uhash | UInt256(Int(hbytes[29]) << 16)
    uhash = uhash | UInt256(Int(hbytes[30]) << 8)
    uhash = uhash | UInt256(Int(hbytes[31]))
    return uhash
  }
}
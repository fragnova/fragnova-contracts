from ethereum import utils, abi, transactions, tester, state_transition

multisend_contract = "60606040526040516099380380609983398101604052805160805160a05191830192019081518351600091146032576002565b5b8351811015608d578381815181101560025790602001906020020151600160a060020a031660008483815181101560025790602001906020020151604051809050600060405180830381858888f150505050506001016033565b81600160a060020a0316ff".decode('hex')
multisend_abi = [{"inputs":[{"name":"recipients","type":"address[]"},{"name":"amounts","type":"uint256[]"},{"name":"remainder","type":"address"}],"type":"constructor"},{"anonymous":False,"inputs":[{"indexed":True,"name":"recipient","type":"address"},{"indexed":False,"name":"amount","type":"uint256"}],"name":"SendFailure","type":"event"}]


def make_trustless_multisend(payouts, remainder, gasprice=20 * 10**9):
    """
    Creates a transaction that trustlessly sends money to multiple recipients, and any
    left over (unsendable) funds to the address specified in remainder.
    Arguments:
      payouts: A list of (address, value tuples)
      remainder: An address in hex form to send any unsendable balance to
      gasprice: The gas price, in wei
    Returns: A transaction object that accomplishes the multisend.
    """
    ct = abi.ContractTranslator(multisend_abi)
    addresses = [utils.normalize_address(addr) for addr, value in payouts]
    values = [value for addr, value in payouts]
    cdata = ct.encode_constructor_arguments([addresses, values, utils.normalize_address(remainder)])
    tx = transactions.Transaction(
        0,
        gasprice,
        50000 + len(addresses) * 35000,
        '',
        sum(values),
        multisend_contract + cdata)
    tx.v = 27
    tx.r = 0x0DA0DA0DA0DA0DA0DA0DA0DA0DA0DA0DA0DA0DA0DA0DA0DA0DA0DA0DA0DA0
    tx.s = 0x0DA0DA0DA0DA0DA0DA0DA0DA0DA0DA0DA0DA0DA0DA0DA0DA0DA0DA0DA0DA0
    while True:
        try:
            tx.sender
            return tx
        except Exception, e:
            # Failed to generate public key
            tx.r += 1

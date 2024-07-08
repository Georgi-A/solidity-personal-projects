const { StandardMerkleTree } =  require("@openzeppelin/merkle-tree");
const fs =  require("fs");

// let mintAddresses = [
//     ["0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", "1"],
//     ["0x70997970C51812dc3A010C7d01b50e0d17dc79C8", "1"],
//     ["0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC", "1"],
//     ["0x90F79bf6EB2c4f870365E785982E1f101E93b906", "1"],
//     ["0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65", "1"],
//     ["0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc", "1"]
// ]

let mintAddresses = [
    ["0x5B38Da6a701c568545dCfcB03FcB875f56beddC4", "5"],
    ["0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2", "1"],
    ["0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC", "6"],
    ["0x90F79bf6EB2c4f870365E785982E1f101E93b906", "10"],
    ["0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65", "16"],
    ["0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc", "20"]
]

const tree = StandardMerkleTree.of(mintAddresses, ["address", "uint256"]);

console.log('Merkle Root:', tree.root);

fs.writeFileSync("tree.json", JSON.stringify(tree.dump()));

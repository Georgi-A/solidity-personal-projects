const { StandardMerkleTree } =  require("@openzeppelin/merkle-tree");
const fs =  require("fs");

const tree = StandardMerkleTree.load(JSON.parse(fs.readFileSync("tree.json", "utf8")));

for (const [i, v] of tree.entries()) {
  if (v[0] === '0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2') {
    const proof = tree.getProof(i);
    console.log('Value:', v);
    console.log('Proof:', proof);
  }
}
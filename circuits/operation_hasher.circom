pragma circom 2.0.0;

include "../node_modules/circomlib/circuits/poseidon.circom";
include "../node_modules/circomlib/circuits/mux1.circom";
include "../node_modules/circomlib/circuits/comparators.circom";
include "./tree.circom";

//circom circuits/zk_session_key_generation_v2.circom --r1cs --wasm --sym --c -o build
//snarkjs info -r build/zk_session_key_generation_v2.r1cs
//snarkjs r1cs print build/zk_session_key_generation_v2.r1cs build/zk_session_key_generation_v2.sym


//# Powers of Tau
//snarkjs powersoftau new bn128 16 powersOfTau28_hez_final_16.ptau -v
//snarkjs powersoftau contribute powersOfTau28_hez_final_16.ptau build/pot16_0001.ptau --name="First contribution" -v

//# Phase 2
//snarkjs powersoftau prepare phase2 build/pot16_0001.ptau build/pot16_final.ptau -v
//snarkjs groth16 setup build/zk_session_key_generation_v2.r1cs build/pot16_final.ptau build/zk_session_key_generation_0000.zkey
//snarkjs zkey contribute build/zk_session_key_generation_0000.zkey build/zk_session_key_generation_0001.zkey --name="Second Contributor" -v


//# Export verfication key
//snarkjs zkey export verificationkey build/zk_session_key_generation_0001.zkey build/zk_session_key_generation_verification_key.json


//# Export Contract
//snarkjs zkey export solidityverifier build/zk_session_key_generation_0001.zkey build/zk_session_key_generation_verifier.sol

template OperationHasher() {

    signal input accountIdentifier;
    signal input secret;
    signal input op;

    signal output opHash;


    component accountInformationHasher = Poseidon(1);
    accountInformationHasher.inputs[0] <== accountIdentifier + secret;

    component opHasher = Poseidon(2);
    opHasher.inputs[0] <== accountInformationHasher.out;
    opHasher.inputs[1] <== op;

    opHash <== opHasher.out;

}

//component main {public [op, accountIdentifier]} = OperationHasher(4);

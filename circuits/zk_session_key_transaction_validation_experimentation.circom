pragma circom 2.0.0;

include "../node_modules/circomlib/circuits/poseidon.circom";
include "./tree.circom";
include "./operation_hasher.circom";


//circom circuits/zk_session_key_transaction_validation.circom --r1cs --wasm --sym --c -o build/zk_session_key_transaction_validation_1_17_17
//snarkjs info -r build/zk_session_key_transaction_validation_1_17_17/zk_session_key_transaction_validation.r1cs
//snarkjs r1cs print build/zk_session_key_transaction_validation_1_17_17/zk_session_key_transaction_validation.r1cs build/zk_session_key_transaction_validation_1_17_17/zk_session_key_transaction_validation.sym


//# Powers of Tau: https://github.com/privacy-scaling-explorations/perpetualpowersoftau
//snarkjs powersoftau new bn128 14 powersOfTau28_hez_final_14.ptau -v
//snarkjs powersoftau contribute powersOfTau28_hez_final_14.ptau build/zk_session_key_transaction_validation_1_17_17/pot14_0001.ptau --name="First contribution" -v

//# Phase 2
//snarkjs powersoftau prepare phase2 build/zk_session_key_transaction_validation_1_17_17/pot14_0001.ptau build/zk_session_key_transaction_validation_1_17_17/pot14_final.ptau -v
//snarkjs groth16 setup build/zk_session_key_transaction_validation_1_17_17/zk_session_key_transaction_validation.r1cs build/zk_session_key_transaction_validation_1_17_17/pot14_final.ptau build/zk_session_key_transaction_validation_1_17_17/zk_session_key_transaction_validation_0000.zkey
//snarkjs zkey contribute build/zk_session_key_transaction_validation_1_17_17/zk_session_key_transaction_validation_0000.zkey build/zk_session_key_transaction_validation_1_17_17/zk_session_key_transaction_validation_0001.zkey --name="Second Contributor" -v


//# Export verfication key
//snarkjs zkey export verificationkey build/zk_session_key_transaction_validation_1_17_17/zk_session_key_transaction_validation_0001.zkey build/zk_session_key_transaction_validation_1_17_17/zk_session_key_transaction_validation_verification_key.json


//# Export Contract
//snarkjs zkey export solidityverifier build/zk_session_key_transaction_validation_1_17_17/zk_session_key_transaction_validation_0001.zkey build/zk_session_key_transaction_validation_1_17_17/zk_session_key_transaction_validation_verifier.sol

template ZkSessionTransactionValidation(transactionNumber, smartContractTreeLevels, toTreeLevels) {

    signal input accountIdentifier;
    signal input sessionKeyIdentifier;
    signal input allowedSmartContractTreeRoot;
    signal input allowedToTreeRoot;
    signal input op;
    //signal input validUntil;
    //signal input validAfter;

    //Extracted by the smart contract account (validateUserOp) from the user operation calldata 
    signal input dest[transactionNumber];
    signal input value[transactionNumber];
    signal input functionSelector[transactionNumber]; //(ERC20, transfer value) Hex: 0xa9059cbb
    signal input erc20TransferTo[transactionNumber];
    //signal input erc20amount[transactionNumber];
        
    signal input EthToSiblings[transactionNumber][toTreeLevels];
    signal input EthToPathIndices[transactionNumber][toTreeLevels];
    signal input allowedSmartContractCallSiblings[transactionNumber][smartContractTreeLevels];
    signal input allowedSmartContractCallPathIndices[transactionNumber][smartContractTreeLevels];
    signal input Erc20ToAddressSiblings[transactionNumber][toTreeLevels];
    signal input Erc20ToAddressPathIndices[transactionNumber][toTreeLevels];


    signal output sessionRoot;
    signal output opHash;

    signal toTreeRootPerTransaction[transactionNumber];
    signal computedToTreeRootPerTransaction[transactionNumber];
    signal smartContractCallTreeRootPerTransaction[transactionNumber];
    signal computedSmartContractCallTreeRootPerTransaction[transactionNumber];
    signal erc20ToTreeRootPerTransaction[transactionNumber];
    signal computedErc20ToTreeRootPerTransaction[transactionNumber];


    //Compute session tree root
    component sessionTree01 = Poseidon(2);
    sessionTree01.inputs[0] <== accountIdentifier;
    sessionTree01.inputs[1] <== sessionKeyIdentifier;

    component sessionTree23 = Poseidon(2);
    sessionTree23.inputs[0] <== allowedSmartContractTreeRoot;
    sessionTree23.inputs[1] <== allowedToTreeRoot;

    component sessionTree = Poseidon(2);
    sessionTree.inputs[0] <== sessionTree01.out;
    sessionTree.inputs[1] <== sessionTree23.out;
    sessionRoot <== sessionTree.out;


    component isZeroEthAmount[transactionNumber];
    for (var i=0; i<transactionNumber; i++) {
        isZeroEthAmount[i] = IsZero();
        isZeroEthAmount[i].in <== value[i];
    }
    component ethTransferToAddressInclusionValidity[transactionNumber];
    for (var i=0; i<transactionNumber; i++) {
        ethTransferToAddressInclusionValidity[i] = MerkleTreeInclusionProof(toTreeLevels);
        ethTransferToAddressInclusionValidity[i].leaf <== dest[i];
        for (var j=0; j<toTreeLevels; j++) {
            ethTransferToAddressInclusionValidity[i].siblings[j] <== EthToSiblings[i][j];
            ethTransferToAddressInclusionValidity[i].pathIndices[j] <== EthToPathIndices[i][j];
        }
    }
    for (var i=0; i<transactionNumber; i++) {
        toTreeRootPerTransaction[i] <== allowedToTreeRoot * (1 - isZeroEthAmount[i].out);
        computedToTreeRootPerTransaction[i] <== ethTransferToAddressInclusionValidity[i].root * (1 - isZeroEthAmount[i].out);
        toTreeRootPerTransaction[i] === computedToTreeRootPerTransaction[i];
    }


    
    component isZeroFunctionSelector[transactionNumber];
    for (var i=0; i<transactionNumber; i++) {
        isZeroFunctionSelector[i] = IsZero();
        isZeroFunctionSelector[i].in <== functionSelector[i];
    }
    component callSmartContractAddressInclusionValidity[transactionNumber];
    for (var i=0; i<transactionNumber; i++) {
        callSmartContractAddressInclusionValidity[i] = MerkleTreeInclusionProof(smartContractTreeLevels);
        callSmartContractAddressInclusionValidity[i].leaf <== dest[i];
        for (var j=0; j<smartContractTreeLevels; j++) {
            callSmartContractAddressInclusionValidity[i].siblings[j] <== allowedSmartContractCallSiblings[i][j];
            callSmartContractAddressInclusionValidity[i].pathIndices[j] <== allowedSmartContractCallPathIndices[i][j];
        }
    }
    for (var i=0; i<transactionNumber; i++) {
        smartContractCallTreeRootPerTransaction[i] <== allowedSmartContractTreeRoot * (1 - isZeroFunctionSelector[i].out);
        computedSmartContractCallTreeRootPerTransaction[i] <== callSmartContractAddressInclusionValidity[i].root * (1 - isZeroFunctionSelector[i].out);
        smartContractCallTreeRootPerTransaction[i] === computedSmartContractCallTreeRootPerTransaction[i];
    }


    //2835717307 transfer(to, amount) function selector
    component isErc20Transfer[transactionNumber];
     for (var i=0; i<transactionNumber; i++) {
        isErc20Transfer[i] = IsEqual();
        isErc20Transfer[i].in[0] <== 2835717307;
        isErc20Transfer[i].in[1] <== functionSelector[i];
    }
    component erc20TransferToAddressInclusionValidity[transactionNumber];
    for (var i=0; i<transactionNumber; i++) {
        erc20TransferToAddressInclusionValidity[i] = MerkleTreeInclusionProof(toTreeLevels);
        erc20TransferToAddressInclusionValidity[i].leaf <== erc20TransferTo[i];
        for (var j=0; j<toTreeLevels; j++) {
            erc20TransferToAddressInclusionValidity[i].siblings[j] <== Erc20ToAddressSiblings[i][j];
            erc20TransferToAddressInclusionValidity[i].pathIndices[j] <== Erc20ToAddressPathIndices[i][j];
        }
    }
    for (var i=0; i<transactionNumber; i++) {
        erc20ToTreeRootPerTransaction[i] <== allowedToTreeRoot * isErc20Transfer[i].out;
        computedErc20ToTreeRootPerTransaction[i] <== erc20TransferToAddressInclusionValidity[i].root * isErc20Transfer[i].out;
        erc20ToTreeRootPerTransaction[i] === computedErc20ToTreeRootPerTransaction[i];
    }


    component operationHasher = OperationHasher();
    operationHasher.accountIdentifier <== accountIdentifier + sessionKeyIdentifier;
    operationHasher.secret <== sessionRoot;
    operationHasher.op <== op;

    opHash <== operationHasher.opHash;

}
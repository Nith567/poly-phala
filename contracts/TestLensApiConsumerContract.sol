
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

// import "@openzeppelin/contracts/access/Ownable.sol";
// import "./PhatRollupAnchor.sol";

// contract TestLensApiConsumerContract is PhatRollupAnchor, Ownable {
// event ResponseReceived(uint reqId,  address pair, uint256 value);
//     event ErrorReceived(uint reqId, address pair, uint256 errno);

//     uint constant TYPE_RESPONSE = 0;
//     uint constant TYPE_ERROR = 2;

//     mapping(uint => address) requests;
//     uint nextRequest = 1;

//     constructor(address phatAttestor) {
//         _grantRole(PhatRollupAnchor.ATTESTOR_ROLE, phatAttestor);
//     }

//     function setAttestor(address phatAttestor) public {
//         _grantRole(PhatRollupAnchor.ATTESTOR_ROLE, phatAttestor);
//     }

//     function request(address profileId) public {
//         // assemble the request
//         uint id = nextRequest;
//         requests[id] = profileId;
//         _pushMessage(abi.encode(id, profileId));
//         nextRequest += 1;
//     }

//     // For test
//     // function malformedRequest(bytes calldata malformedData) public {
//     //     uint id = nextRequest;
//     //     requests[id] = "malformed_req";
//     //     _pushMessage(malformedData);
//     //     nextRequest += 1;
//     // }

//     function _onMessageReceived(bytes calldata action) internal override {
//         require(action.length == 32 * 3, "cannot parse action");
//         (uint respType, uint id, uint256 data) = abi.decode(
//             action,
//             (uint, uint, uint256)
//         );
//         if (respType == TYPE_RESPONSE) {
//             emit ResponseReceived(id, requests[id], data);
//             delete requests[id];
//         } else if (respType == TYPE_ERROR) {
//             emit ErrorReceived(id, requests[id], data);
//             delete requests[id];
//         }
//     }
// }

// import "@openzeppelin/contracts/access/Ownable.sol";
import "./PhatRollupAnchor.sol";
import "./polygonZKEVMContracts/PolygonZkEVMBridge.sol";
import "hardhat/console.sol";


contract TestLensApiConsumerContract is PhatRollupAnchor{
    // event ResponseReceived(uint reqId, string pair, uint256 value,uint n1,uint n2,string[32] data,string n3,uint n4 ,string n5,uint n6,string n7,uint n8,uint n9);
    event ResponseReceived(
    uint respType,
    uint id,
    uint32 n,
    uint n1,
    bytes32 n2,
    bytes32[32] data,
    bytes n3,
    uint n4,
    address n5,
    uint32 n6,
    address n7,
    uint32 n8,
    bytes32 n9
);
    event ResponseReceived2(
    uint respType,
    uint id
);

    mapping(uint => address) public requestsByUsers;

    event ErrorReceived(  
          uint respType,
    uint id,
    uint32 n1
  );

    uint constant TYPE_RESPONSE = 0;
    uint constant TYPE_ERROR = 2;
    event ResponseReceived3(uint reqId,  address pair,bytes32[32] data,uint32 n,bytes32 n2,bytes32 n9,uint32 n8,address n7,uint32 n6,address n5,uint256,bytes n3);
//     uint32 n;
//     uint n1;
//     bytes32 n2;
// bytes32 [32] data;
//     uint n4;
//     address n5;
//     bytes  n3;
//     uint32 n6;
//     address n7;
//      uint32 n8;
//      bytes32 n9;

    //   mapping(uint => address) public requestsByUsers;

    mapping(uint => address) requests;
    uint nextRequest = 1;
    constructor(address phatAttestor) {
        _grantRole(PhatRollupAnchor.ATTESTOR_ROLE, phatAttestor);
    }

    function setAttestor(address phatAttestor) public {
        _grantRole(PhatRollupAnchor.ATTESTOR_ROLE, phatAttestor);
    }

   function request(address add) public {
        address sender = msg.sender;
        uint id = nextRequest;
        requests[id] = add;
        requestsByUsers[id] = sender;
        _pushMessage(abi.encode(id, add));
        nextRequest += 1;
    }
   

    // // For test
    // function malformedRequest(bytes calldata malformedData) public {
    //     uint id = nextRequest;
    //     requests[id] = "";
    //     _pushMessage(malformedData);
    //     nextRequest += 1;
    // }
    // uintCoder,uintCoder,stringCoder,uintCoder,bytesCoder,bytesArrayCoder,stringCoder,stringCoder,addressCoder,uintCoder,addressCoder,uintCoder32,bytesCoder
// function claim() public{
//              PolygonZkEVMBridge bridgeContract = PolygonZkEVMBridge(0xF6BEEeBB578e214CA9E23B0e9683454Ff88Ed2A7);
//             bridgeContract.claimMessage(data,n,n2,n9,n8,n7,n6,n5,n4,n3);
// }
    function _onMessageReceived(bytes calldata action) internal override {
        // (uint respType, uint id,uint32 n,bytes32 n2,bytes32[32] memory data,bytes memory n3,uint256 n4,address n5,uint32 n6,address n7, uint32 n8, bytes32 n9) = abi.decode(
        //     action,
        //     (  uint, uint,    uint32, bytes32,  bytes32[32],   bytes,           uint256,   address,    uint32,   address,    uint32,      bytes32)
        // );
        (uint respType, uint id,bytes32[32] memory data,uint32 n,bytes32 n2, bytes32 n9,uint32 n8,address n7,uint32 n6,address n5,uint256 n4,bytes memory n3) = abi.decode(
            action,
            (  uint, uint,bytes32[32],uint32, bytes32,bytes32,uint32,address,uint32,address,uint256,bytes)
        );
        // console.logUint(id);
//         n=n;
//      n1=n1;
//     n2=n2;
// data=data;
//     n4=n4;
//     n5=n5;
//      n3=n3;
//      n6=n6;
//      n7=n7;
//       n8=n8;
//       n9=n9;

    // event ResponseReceived3(uint reqId,  address pair,bytes32[32] data,bytes32 n2,address n7);
         emit ResponseReceived3(id, requests[id],data,n,n2,n9,n8,n7,n6,n5,n4,n3);
            PolygonZkEVMBridge bridgeContract = PolygonZkEVMBridge(0xF6BEEeBB578e214CA9E23B0e9683454Ff88Ed2A7);
            bridgeContract.claimMessage(data,n,n2,n9,n8,n7,n6,n5,0,n3);
            //   delete requestsByUsers[id];
            delete requests[id];
   
    }
} 







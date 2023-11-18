
import "@phala/pink-env";
import { Coders } from "@phala/ethers";
import { AddressCoder, BytesCoder } from "@phala/ethers/lib.commonjs/abi/coders";
import { parse } from "path";
import { ethers } from "ethers";
import { Console } from "console";
type HexString = `0x${string}`
import { encodeAbiParameters, decodeAbiParameters } from 'viem'
import { Coder } from "@ethersproject/abi/lib/coders/abstract-coder";


const addressCoder = new Coders.AddressCoder("address");
const addressArrayCoder = new Coders.ArrayCoder(addressCoder, 32, "address");
const uintCoder = new Coders.NumberCoder(32, false, "uint256");
const uintCoder5 = new Coders.NumberCoder(256, false, "uint256");
const bytesCoder3 = new Coders.FixedBytesCoder(32,"bytes")
// const bytescoder32=new Coders.BytesCoder
// const uintCoder32= new Coders.NumberCoder(32, false, "32");

const stringCoder = new Coders.StringCoder("string")

const uintCoder32 = new Coders.NumberCoder(32, false, "uint32");
const bytesArrayCoder = new Coders.ArrayCoder(bytesCoder3, 32, "bytes");

// ,bytesCoder3      it's importatnt bro's
// uint, uint, uint32,uint,bytes32,bytes32[32],bytes memory,uint,address,uint32,string,uint32,bytes32

// bytes32,uint32,address,uint32,address,uint256
function encodeReply(reply: [any,any,any,any,any,any,any,any,any,any,any,any]): HexString {
  // return Coders.encode([uintCoder,uintCoder,uintCoder32,bytesCoder,bytesArrayCoder,bytesCoder,uintCoder,addressCoder,uintCoder32,addressCoder,uintCoder32,bytesCoder], reply) as HexString;
  return Coders.encode([uintCoder,uintCoder,bytesArrayCoder,uintCoder,bytesCoder3,bytesCoder3,uintCoder,addressCoder,uintCoder,addressCoder,uintCoder5,bytesCoder3], reply) as HexString;
}
function encodeReply2(reply: [any,any,any]): HexString {
  const encodedData = encodeAbiParameters(
    [
      { name: 'param1', type: 'uint' },
      { name: 'param2', type: 'uint' },
      { name: 'param3', type: 'bytes[32]' },
      // { name: 'param4', type: 'bytes32' },
      // { name: 'param5', type: 'bytes[32]' },
      // { name: 'param6', type: 'string[]' },
      // { name: 'param7', type: 'string' },
      // { name: 'param8', type: 'string' },
      // { name: 'param9', type: 'string' },
      // { name: 'param10', type: 'uint' },
      // { name: 'param11', type: 'string' },
      // { name: 'param12', type: 'uint' },
      // { name: 'param13', type: 'string' },
    ],
    reply
  ) as HexString;

  return encodedData;
}

// (uint, uint,         uint32,   uint,  bytes32,  bytes32[32],                bytes,           uint256,   address,    uint32,   address,    uint32,      bytes32)
// function encode(reply:number,)
const TYPE_RESPONSE = 0;
const TYPE_ERROR = 2;

enum Error {
  BadLensProfileId = "BadLensProfileId",
  FailedToFetchData = "FailedToFetchData",
  FailedToDecode = "FailedToDecode",
  MalformedRequest = "MalformedRequest",
  BadRequestString = "BadRequestString"
}

function errorToCode(error: Error): number {
  switch (error) {
    case Error.BadLensProfileId:
      return 1;
    case Error.FailedToFetchData:
      return 2;
    case Error.FailedToDecode:
      return 3;
    case Error.MalformedRequest:
      return 4;
    default:
      return 0;
  }
}

function isHexString(str: string): boolean {
  const regex = /^0x[0-9a-f]+$/;
  return regex.test(str.toLowerCase());
}

function stringToHex(str: string): string {
  var hex = "";
  for (var i = 0; i < str.length; i++) {
    hex += str.charCodeAt(i).toString(16);
  }
  return "0x" + hex;
}


function BridgeFetch(apiUrl: string, reqStr: string):any {

  // const bridgeApiEndpoint =`https://bridge-api.public.zkevm-test.net/bridges/${reqStr}`;
  const http =`${apiUrl}${reqStr}`;

  let headers = {
    "Content-Type": "application/json",
    "User-Agent": "phat-contract",
  };

  const response = pink.httpRequest({
    url:http,
    method: "GET",
    headers,
    returnTextBody: true
  });
  if (response.statusCode !== 200) {
    console.log(
      `wrong 200: ${response.statusCode}, error: ${
         response.body
      }}`
    );
    throw Error.FailedToFetchData;
  }
  console.info(response);
  let respBody = response.body;
  if (typeof respBody !== "string") {
    throw Error.FailedToDecode;
  }
  return JSON.parse(respBody);
}


function BridgeFetch2(deposit_cnt:string, net_id: number):any {
  const bridgeApiEndpoint2 =`https://bridge-api.public.zkevm-test.net/merkle-proof?deposit_cnt=${deposit_cnt}&net_id=${net_id}`

  let headers = {
    "Content-Type": "application/json",
    "User-Agent": "phat-contract",
  };

  const response = pink.httpRequest({
    url:bridgeApiEndpoint2,
    method: "GET",
    headers,
    returnTextBody: true
  });
  if (response.statusCode !== 200) {
    console.log(
      `wrong 200: ${response.statusCode}, error: ${
         response.body
      }}`
    );
    throw Error.FailedToFetchData;
  }
  console.info(response);
  let respBody = response.body;
  if (typeof respBody !== "string") {
    throw Error.FailedToDecode;
  }
  return JSON.parse(respBody);
}

function parseProfileId(hexx: string) {
  // var hex = hexx.toString();
  // if (!isHexString(hex)) {
  //   throw Error.BadLensProfileId;
  // }
  // hex = hex.slice(2);
  // var str = "";
  // for (var i = 0; i < hex.length; i += 2) {
  //   const ch = String.fromCharCode(parseInt(hex.substring(i, i + 2), 16));
  //   str += ch;
  // }
  // return str;
  // const hex = hexx.startsWith('0x') ? hexx.slice(2) : hexx;

  // if (!isHexString(hex)) {
  //   throw Error.BadLensProfileId;
  const address = ethers.utils.getAddress(hexx);
  return address;  

}

//   // Convert hex to BigNumber
//   const bigNumber = ethers.BigNumber.from('0x' + hex);

//   // Use ethers.js to format the address
//   const address = ethers.utils.getAddress(bigNumber);

//   return address;
// }

function parseReqStr(hexStr: string): string {
  var hex = hexStr.toString();
  if (!isHexString(hex)) {
    throw Error.BadRequestString;
  }
  hex = hex.slice(2);
  var str = "";
  for (var i = 0; i < hex.length; i += 2) {
    const ch = String.fromCharCode(parseInt(hex.substring(i, i + 2), 16));
    str += ch;
  }
  return str;
}
function parseHexToAddress(hexStr: string): string {
  // Remove '0x' prefix if present
  const hex = hexStr.startsWith('0x') ? hexStr.slice(2) : hexStr;

  // Check if the input is a valid hex string
  if (!/^[0-9A-Fa-f]*$/.test(hex)) {
    console.log("Invalid hex string");
  }

  // Extract the last 20 bytes (40 characters) of the hex string
  const addressHex = hex.slice(-40);

  // console.log("ad " +addressHex)
  // Convert the extracted hex to Ethereum address
  const ethereumAddress = '0x' + addressHex;

  return ethereumAddress;
}

export default function main(request: HexString, settings: string): HexString {
  console.log(`handle reqs are : ${request}`);
  let requestId, encodedAddress,ar;
  try {
    [requestId, encodedAddress] = Coders.decode([uintCoder, addressCoder], request);

    console.log("bitch " + encodedAddress)

  } catch (error) {
    console.info("Malformed request received");

    // return encodeReply([TYPE_ERROR, 0]);
    // return encodeReply([TYPE_ERROR, 0, 'string','0',['ysd','sdf','2','w','w','w','w','w','w','w','w','w','w','w','w','w','w','w','w','w','w','w','w','w','w','w','w','w','w','w','w','w'],'23','string','0x333De8E1bac69F3F44C8a7ffFE6c9559e7CD83D8',3,'0x333De8E1bac69F3F44C8a7ffFE6c9559e7CD83D8',23,'0x54ebc53b8763a0da62d0ab89520117c1eed5151cec708cd44fda441b4feced9d']);
  }
  console.log()
  const add = parseHexToAddress(encodedAddress as string)
  console.log(`Request received  ${add}`);
  // const parsedHexReqStr = parseReqStr(encodedReqStr as string);
  // console.log(`Request received for profile ${parsedHexReqStr}`);
console.log("")
  try {
    console.info('try here ')
    // const respData = Bridge(secrets, parsedHexReqStr);
    const respData = BridgeFetch(settings, add);
    let stats1: any = respData.deposits[0].deposit_cnt;
    let stats2: any= respData.deposits[0].network_id;
    let stats10: any = respData.deposits[0].orig_net;
    let stats9: any = respData.deposits[0].orig_addr;
    let stats8: any = respData.deposits[0].dest_net;
    let stats7: any= respData.deposits[0].dest_addr;
    let stats6: any = respData.deposits[0].amount;
    let stats5: any = respData.deposits[0].metadata;
    
const respData2=BridgeFetch2(stats1,stats2)   

let stat3:any=respData2.proof.main_exit_root
let stat11:any=respData2.proof.rollup_exit_root

let stats4:any[]=respData2.proof.merkle_proof
// console.info("bitstats3)
console.info("makki : ",[stats1])
    return encodeReply([TYPE_RESPONSE, requestId,stats4,stats1,stat3,stat11,stats10,stats9,stats8,stats7,stats6,stats5]);
    // return encodeReply([TYPE_RESPONSE, requestId,stats1,stat3,stats4,stats5,stats6,stats7,stats8,stats9,stats10,stat11]);
        // return encodeReply2([stats1,stats2,stat3,stats4,stats5,stats6,stats7,stats8,stats9,stats10,stat11])
  }
 catch (error) {
    if (error === Error.FailedToFetchData) {
      throw error;
    } else {
      // ,number,number,string,string,number,string,number,string,number,number
      // Otherwise, tell the client we cannot process it
      console.log("errors", [TYPE_ERROR, requestId,"0x00000000000000000000000000000000000000000000000000000000000002b8"]);
      // return encodeReply([TYPE_ERROR, requestId]);
      return encodeReply([342, 234,"0x123456789abcdef","sldkfj","0xsdlfjlsdkfj",'sdf','sdf','sdf','dsf','sd','2es','sd']);
      // uintCoder,uintCoder,stringCoder,uintCoder,bytesCoder,bytesArrayCoder,stringCoder,stringCoder,addressCoder,uintCoder,addressCoder,uintCoder32,bytesCoder
    }
  }
}33
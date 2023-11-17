import { expect } from "chai";
import { type Contract, type Event } from "ethers";
import { ethers } from "hardhat";
import { execSync } from "child_process";

async function waitForResponse(consumer: Contract, event: Event) {
  const [, data] = event.args!;
  // Run Phat Function
  // const result = execSync(`phat-fn run --json dist/index.js -a ${data} https://api-mumbai.lens.dev/`).toString();
  const result = execSync(`phat-fn run --json dist/index.js -a ${data} https://bridge-api.public.zkevm-test.net/bridges/`).toString();
  const json = JSON.parse(result);
  const action = ethers.utils.hexlify(ethers.utils.concat([
    new Uint8Array([0]),
    json.output,
  ]));
  // Make a response
  const tx = await consumer.rollupU256CondEq(
    // cond
    [],
    [],
    // updates
    [],
    [],
    // actions
    [action],
  );
  const receipt = await tx.wait();
  return receipt.events;
}

describe("TestLensApiConsumerContract", function () {
  it("Push and receive message", async function () {
    // Deploy the contract
    const [deployer] = await ethers.getSigners();
    const TestLensApiConsumerContract = await ethers.getContractFactory("TestLensApiConsumerContract");
    const consumer = await TestLensApiConsumerContract.deploy(deployer.address);

    // Make a request
    const profileId = "0x65ce916b587482DE215139Fa266081134AC6a1Eb";
    const tx = await consumer.request(profileId);
    const receipt = await tx.wait();
    const reqEvents = receipt.events;
    // expect(reqEvents![0]).to.have.property("event", "MessageQueued");
    // console.log(reqEvents?.map(e=>console.log(e.args?.at(2))))
    // console.log(reqEvents)
    // Wait for Phat Function response
const respEvents = await waitForResponse(consumer, reqEvents![0])
console.log(respEvents);
console.log(respEvents?.map((e:any) => {
  const args = e.args;
  if (args) {
      const address = args[2]
      const l=args[3];
      const r=args[4];
      const r1=args[5];
      const r2=args[6];
      const r3=args[7];
      const r4=args[8];
      const r5=args[9];
      const r6=args[10];
      const r7=args[11];
      console.log('Address:', address,l,r,r1,r2,r3,r4,r5,r6,r7);
  }
}));
    // Check response data
    expect(respEvents[0]).to.have.property("event", "ResponseReceived3");
    // const [reqId, pair, value] = respEvents[0].args;
  //   expect(ethers.BigNumber.isBigNumber(reqId)).to.be.true;
  //   expect(pair).to.equal(profileId);
  //   expect(ethers.BigNumber.isBigNumber(value)).to.be.true;
  // });
  })
});

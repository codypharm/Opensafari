const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Token", function () {
  /*it("Should return the new greeting once it's changed", async function () {
    const Greeter = await ethers.getContractFactory("Greeter");
    const greeter = await Greeter.deploy("Hello, world!");
    await greeter.deployed();

    expect(await greeter.greet()).to.equal("Hello, world!");

    const setGreetingTx = await greeter.setGreeting("Hola, mundo!");

    // wait until the transaction is mined
    await setGreetingTx.wait();

    expect(await greeter.greet()).to.equal("Hola, mundo!");
  });*/

  it("should return new balance of deployer", async () => {
    const Token = await ethers.getContractFactory("OpenSafariToken");
    const token = await Token.deploy(
      ethers.utils.parseUnits("1000000", "ether")
    );
    await token.deployed();

    const [acct1, acct2] = await ethers.getSigners();

    expect(await token.balanceOf(acct1.address)).to.equal(
      ethers.utils.parseUnits("1000000", "ether")
    );

    const mintTx = await token.mint(
      ethers.utils.parseUnits("1000000", "ether")
    );

    await mintTx.wait();

    expect(await token.balanceOf(acct1.address)).to.equal(
      ethers.utils.parseUnits("2000000", "ether")
    );

    console.log(await token.balanceOf(acct1.address));
  });
});

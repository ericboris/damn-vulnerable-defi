const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('[Challenge] Truster', function () {
    let deployer, attacker;

    const TOKENS_IN_POOL = ethers.utils.parseEther('1000000');

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, attacker] = await ethers.getSigners();

        const DamnValuableToken = await ethers.getContractFactory('DamnValuableToken', deployer);
        const TrusterLenderPool = await ethers.getContractFactory('TrusterLenderPool', deployer);

        this.token = await DamnValuableToken.deploy();
        this.pool = await TrusterLenderPool.deploy(this.token.address);

        await this.token.transfer(this.pool.address, TOKENS_IN_POOL);

        expect(
            await this.token.balanceOf(this.pool.address)
        ).to.equal(TOKENS_IN_POOL);

        expect(
            await this.token.balanceOf(attacker.address)
        ).to.equal('0');
    });

    it('Exploit', async function () {
        /** CODE YOUR EXPLOIT HERE  */
        const trusterAttackerContractFactory = await ethers.getContractFactory(
            'TrusterAttacker', deployer
        );
        this.trusterAttacker = await trusterAttackerContractFactory
            .connect(attacker)
            .deploy(
                this.pool.address, 
                this.token.address
            );

        /*
            Vulnerability:
                The pool.flashLoan function calls the received target address with any received
                data without checking the target or data first. This allows an attacker manipulate
                the pool into granting an unlimited token allowance to themselves which the
                attacker then uses to withdraw the pool's token balance.
            Recommendation:
                The pool.flashLoan function should restrict the target and/or data fields to
                limit an attacker's ability to make such unverified calls.
        */
        await this.trusterAttacker.connect(attacker).attack();
    });

    after(async function () {
        /** SUCCESS CONDITIONS */

        // Attacker has taken all tokens from the pool
        expect(
            await this.token.balanceOf(attacker.address)
        ).to.equal(TOKENS_IN_POOL);
        expect(
            await this.token.balanceOf(this.pool.address)
        ).to.equal('0');
    });
});


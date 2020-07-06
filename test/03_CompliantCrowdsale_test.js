import { advanceBlock } from "./helpers/advanceToBlock";
import ether from "./helpers/ether";
import VMExceptionRevert from "./helpers/VMExceptionRevert";
import { increaseTimeTo, duration } from "./helpers/increaseTime";
import latestTime from "./helpers/latestTime";
import log from "./helpers/logger";

const BigNumber = web3.BigNumber;
const should = require("chai")
  .use(require("chai-as-promised"))
  .use(require("chai-bignumber")(BigNumber))
  .should();

const Crowdsale = artifacts.require("CompliantCrowdsale");
const Token = artifacts.require("CompliantToken");
const Whitelisting = artifacts.require("Whitelist");

contract("Crowdsale", function([
  owner,
  validator,
  wallet,
  investor,
  unApprovedinvestor
]) {
  const rate = new BigNumber(10);
  const investmentAmount = ether(10);

  before(async function() {
    //Advance to the next block to correctly read time in the solidity "now" function interpreted by testrpc
    await advanceBlock();
  });

  beforeEach(async function() {
    this.startTime = latestTime() + duration.weeks(1);
    this.beforeStartTime = this.startTime - duration.seconds(1);
    this.endTime = this.startTime + duration.weeks(1);
    this.afterEndTime = this.endTime + duration.seconds(1);

    this.whitelisting = await Whitelisting.new();
    this.token = await Token.new();
    this.crowdsale = await Crowdsale.new(
      this.whitelisting.address,
      this.startTime,
      this.endTime,
      rate,
      wallet,
      this.token.address
    );

    const tx1 = await this.token.setWhitelistContract(
      this.whitelisting.address
    );
    log(`setWhitelistContract gasUsed: ${tx1.receipt.gasUsed}`);

    const tx2 = await this.token.transferOwnership(this.crowdsale.address);
    log(`transferOwnership gasUsed: ${tx2.receipt.gasUsed}`);

    const tx3 = await this.whitelisting.approveInvestor(investor);
    log(`approveInvestor gasUsed: ${tx3.receipt.gasUsed}`);

    const tx4 = await this.crowdsale.setNewValidator(validator, {
      from: owner
    });
    log(`setNewValidator gasUsed: ${tx4.receipt.gasUsed}`);
  });

  it("should be created with proper parameters", async function() {
    (await this.crowdsale.whiteListingContract()).should.equal(
      this.whitelisting.address
    );
    (await this.crowdsale.token()).should.equal(this.token.address);
    (await this.crowdsale.wallet()).should.equal(wallet);
    (await this.crowdsale.currentMintNonce()).should.be.bignumber.equal(
      new BigNumber(0)
    );
    (await this.crowdsale.rate()).should.be.bignumber.equal(rate);
    (await this.crowdsale.startTime()).should.be.bignumber.equal(
      this.startTime
    );
    (await this.crowdsale.endTime()).should.be.bignumber.equal(this.endTime);
  });

  describe("buyTokens", function() {
    it("should add to pending mints", async function() {
      await increaseTimeTo(this.startTime);

      const tx = await this.crowdsale.buyTokens(investor, {
        value: investmentAmount
      }).should.be.fulfilled;
      log(`buyTokens gasUsed: ${tx.receipt.gasUsed}`);

      const pendingMint = await this.crowdsale.pendingMints(0);

      pendingMint[0].should.equal(investor);
      pendingMint[1].should.be.bignumber.equal(investmentAmount.mul(rate));
      pendingMint[2].should.be.bignumber.equal(investmentAmount);
    });

    it("it should increase currentMintNonce", async function() {
      await increaseTimeTo(this.startTime);

      const tx = await this.crowdsale.buyTokens(investor, {
        value: investmentAmount
      }).should.be.fulfilled;
      log(`buyTokens gasUsed: ${tx.receipt.gasUsed}`);

      (await this.crowdsale.currentMintNonce()).should.be.bignumber.equal(
        new BigNumber(1)
      );
    });

    it("should log event", async function() {
      await increaseTimeTo(this.startTime);

      const tx = await this.crowdsale.buyTokens(investor, {
        value: investmentAmount
      }).should.be.fulfilled;
      log(`buyTokens gasUsed: ${tx.receipt.gasUsed}`);

      const event = tx.logs.find(e => e.event === "ContributionRegistered");

      should.exist(event);
      event.args.beneficiary.should.equal(investor);
      event.args.tokens.should.be.bignumber.equal(rate.mul(investmentAmount));
      event.args.nonce.should.be.bignumber.equal(new BigNumber(0));
      event.args.weiAmount.should.be.bignumber.equal(investmentAmount);
    });

    it("should revert if beneficiary is address(0)", async function() {
      await increaseTimeTo(this.startTime);

      await this.crowdsale
        .buyTokens("0x0", {
          value: investmentAmount
        })
        .should.be.rejectedWith(VMExceptionRevert);
    });

    it("should throw if beneficiary is not whitelisted", async function() {
      await increaseTimeTo(this.startTime);

      await this.crowdsale
        .buyTokens(unApprovedinvestor, {
          value: investmentAmount
        })
        .should.be.rejectedWith(VMExceptionRevert);
    });

    it("should throw if purchase is not within crowdsale startTime and endTime", async function() {
      await this.crowdsale
        .buyTokens(investor, {
          value: investmentAmount
        })
        .should.be.rejectedWith(VMExceptionRevert);
    });

    it("should throw if purchase amount is zero", async function() {
      await increaseTimeTo(this.startTime);

      await this.crowdsale
        .buyTokens(investor)
        .should.be.rejectedWith(VMExceptionRevert);
    });
  });

  describe("approveMint", function() {
    beforeEach(async function() {
      await increaseTimeTo(this.startTime);

      const tx = await this.crowdsale.buyTokens(investor, {
        value: investmentAmount,
        gasPrice: 0
      }).should.be.fulfilled;
      log(`buyTokens gasUsed: ${tx.receipt.gasUsed}`);
    });

    it("should mint tokens to beneficiary", async function() {
      const tx = await this.crowdsale.approveMint(0, { from: validator }).should
        .be.fulfilled;
      log(`approveMint gasUsed: ${tx.receipt.gasUsed}`);

      (await this.token.balanceOf(investor)).should.be.bignumber.equal(
        rate.mul(investmentAmount)
      );
    });

    it("should forward funds to wallet", async function() {
      const initialBalance = await web3.eth.getBalance(wallet);
      const tx = await this.crowdsale.approveMint(0, {
        gasPrice: 0,
        from: validator
      }).should.be.fulfilled;
      log(`approveMint gasUsed: ${tx.receipt.gasUsed}`);

      const finalBalance = await web3.eth.getBalance(wallet);
      finalBalance.should.be.bignumber.equal(
        initialBalance.add(investmentAmount)
      );
    });

    it("should delete pendingMints after approving them", async function() {
      const tx = await this.crowdsale.approveMint(0, { from: validator }).should
        .be.fulfilled;
      log(`approveMint gasUsed: ${tx.receipt.gasUsed}`);

      const pendingMint = await this.crowdsale.pendingMints(0);

      pendingMint[0].should.equal("0x0000000000000000000000000000000000000000");
      pendingMint[1].should.be.bignumber.equal(new BigNumber(0));
      pendingMint[2].should.be.bignumber.equal(new BigNumber(0));
    });

    it("should log event", async function() {
      const tx = await this.crowdsale.approveMint(0, {
        gasPrice: 0,
        from: validator
      }).should.be.fulfilled;
      log(`approveMint gasUsed: ${tx.receipt.gasUsed}`);

      const event = tx.logs.find(e => e.event === "TokenPurchase");

      should.exist(event);
      event.args.purchaser.should.equal(validator);
      event.args.beneficiary.should.equal(investor);
      event.args.value.should.be.bignumber.equal(investmentAmount);
      event.args.amount.should.be.bignumber.equal(investmentAmount.mul(rate));
    });

    it("should throw if beneficiary is not whitelisted", async function() {
      const tx = await this.whitelisting.disapproveInvestor(investor);

      await this.crowdsale
        .approveMint(0, { from: validator })
        .should.be.rejectedWith(VMExceptionRevert);
    });

    it("should throw if not called by validator", async function() {
      await this.crowdsale
        .approveMint(0, { from: owner })
        .should.be.rejectedWith(VMExceptionRevert);
    });
  });

  describe("rejectMint", function() {
    beforeEach(async function() {
      await increaseTimeTo(this.startTime);

      const tx = await this.crowdsale.buyTokens(investor, {
        value: investmentAmount,
        gasPrice: 0
      }).should.be.fulfilled;
      log(`buyTokens gasUsed: ${tx.receipt.gasUsed}`);
    });

    it("should delete pendingMints", async function() {
      const tx = await this.crowdsale.rejectMint(0, 0, { from: validator })
        .should.be.fulfilled;
      log(`rejectMint gasUsed: ${tx.receipt.gasUsed}`);

      const pendingMint = await this.crowdsale.pendingMints(0);

      pendingMint[0].should.equal("0x0000000000000000000000000000000000000000");
      pendingMint[1].should.be.bignumber.equal(new BigNumber(0));
      pendingMint[2].should.be.bignumber.equal(new BigNumber(0));
    });

    it("should throw if not called by validator", async function() {
      await this.crowdsale
        .rejectMint(0, 0, { from: owner })
        .should.be.rejectedWith(VMExceptionRevert);
    });

    it("should throw for non existing mints", async function() {
      await this.crowdsale
        .rejectMint(1, 0, { from: validator })
        .should.be.rejectedWith(VMExceptionRevert);
    });

    it("should log events", async function() {
      const tx = await this.crowdsale.rejectMint(0, 5, { from: validator })
        .should.be.fulfilled;
      log(`rejectMint gasUsed: ${tx.receipt.gasUsed}`);

      const event = tx.logs.find(e => e.event === "MintRejected");

      should.exist(event);
      event.args.to.should.equal(investor);
      event.args.value.should.be.bignumber.equal(investmentAmount.mul(rate));
      event.args.amount.should.be.bignumber.equal(investmentAmount);
      event.args.nonce.should.be.bignumber.equal(new BigNumber(0));
      event.args.reason.should.be.bignumber.equal(new BigNumber(5));
    });
  });

  describe("setTokenContract", function() {
    it("should set new token contract", async function() {
      const newToken = await Token.new();
      const tx = await this.crowdsale.setTokenContract(newToken.address).should
        .be.fulfilled;
      log(`setTokenContract gasUsed: ${tx.receipt.gasUsed}`);

      (await this.crowdsale.token()).should.equal(newToken.address);
    });

    it("should revert if new token is address(0)", async function() {
      await this.crowdsale
        .setTokenContract("0x0")
        .should.be.rejectedWith(VMExceptionRevert);
    });

    it("should throw if not called by owner", async function() {
      const newToken = await Token.new();

      await this.crowdsale
        .setTokenContract(newToken.address, { from: investor })
        .should.be.rejectedWith(VMExceptionRevert);
    });
  });

  describe("transferTokenOwnership", function() {
    it("should transfer token ownership", async function() {
      const tx = await this.crowdsale.transferTokenOwnership(investor).should.be
        .fulfilled;
      log(`transferTokenOwnership gasUsed: ${tx.receipt.gasUsed}`);

      (await this.token.owner()).should.equal(investor);
    });

    it("should revert if new owner is address(0)", async function() {
      await this.crowdsale
        .transferTokenOwnership("0x0")
        .should.be.rejectedWith(VMExceptionRevert);
    });

    it("should throw if not called by owner", async function() {
      await this.crowdsale
        .transferTokenOwnership(investor, { from: investor })
        .should.be.rejectedWith(VMExceptionRevert);
    });
  });
});

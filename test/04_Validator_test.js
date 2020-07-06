import VMExceptionRevert from "./helpers/VMExceptionRevert";
import log from "./helpers/logger";

const Validator = artifacts.require("Validator");

const should = require("chai")
  .use(require("chai-as-promised"))
  .should();

contract("Validator", function(accounts) {
  let validator;

  beforeEach(async function() {
    validator = await Validator.new();
  });

  it("should have a validator", async function() {
    let result = await validator.validator();
    assert.isTrue(result !== 0);
  });

  it("changes validator after transfer", async function() {
    let other = accounts[1];
    const tx = await validator.setNewValidator(other);
    log(`setNewValidator gasUsed: ${tx.receipt.gasUsed}`);
    let newValidator = await validator.validator();

    assert.isTrue(newValidator === other);
  });

  it("should log event when changing validator", async function() {
    let other = accounts[1];
    const tx = await validator.setNewValidator(other);
    log(`setNewValidator gasUsed: ${tx.receipt.gasUsed}`);
    
    const event = tx.logs.find(e => e.event === "NewValidatorSet");

    should.exist(event);
    event.args.previousOwner.should.equal(accounts[0]);
    event.args.newValidator.should.equal(other);
  });

  it("should prevent non-owners from transfering", async function() {
    const other = accounts[2];
    const currentValidator = await validator.validator.call();
    assert.isTrue(currentValidator !== other);
    await validator
      .setNewValidator(other, { from: other })
      .should.be.rejectedWith(VMExceptionRevert);
  });

  it("should guard ownership against stuck state", async function() {
    let originalValidator = await validator.validator();
    await validator
      .setNewValidator(null, { from: originalValidator })
      .should.be.rejectedWith(VMExceptionRevert);
  });
});

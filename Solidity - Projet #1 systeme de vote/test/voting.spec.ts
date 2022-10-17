import { VotingInstance } from "../types/Voting";

const Voting = artifacts.require('Voting');

contract("Voting", (accounts) => {
  
  const administrator = accounts[0];
  const account1 = accounts[1];
  const account2 = accounts[2];
  const account3 = accounts[3];
  const account4 = accounts[4];

  let votingInstance: VotingInstance;

  describe('Voting tests', () => {
    beforeEach(async () => {
      votingInstance = await Voting.new({ from: administrator });
    });

    it("should not allow status change from other users than administator", async function () {
      try {
        await votingInstance.startProposalsRegistrations({from: account1});
        assert.isTrue(false);
      }
      catch (e: any) {
        assert.equal(e.name, 'Error', 'Expecting error');
        assert.include(e.stack, 'Ownable: caller is not the owner', 'Expecting not owner error');
      }

      try {
        await votingInstance.endProposalsRegistrations({from: account1});
        assert.isTrue(false);
      }
      catch (e: any) {
        assert.equal(e.name, 'Error', 'Expecting error');
        assert.include(e.stack, 'Ownable: caller is not the owner', 'Expecting not owner error');
      }

      try {
        await votingInstance.startVotingSession({from: account1});
        assert.isTrue(false);
      }
      catch (e: any) {
        assert.equal(e.name, 'Error', 'Expecting error');
        assert.include(e.stack, 'Ownable: caller is not the owner', 'Expecting not owner error');
      }

      try {
        await votingInstance.endVotingSession({from: account1});
        assert.isTrue(false);
      }
      catch (e: any) {
        assert.equal(e.name, 'Error', 'Expecting error');
        assert.include(e.stack, 'Ownable: caller is not the owner', 'Expecting not owner error');
      }
    });

    it("should not allow start proposals registrations if there are no voters", async function () {
      try {
        await votingInstance.startProposalsRegistrations({ from: administrator });
        assert.isTrue(false);
      }
      catch (e: any) {
        assert.equal(e.name, 'Error', 'Expecting error');
        assert.include(e.stack, 'There must be at least 1 voter to start the proposal registration process', 'Expecting no voter registered error');
      }
    });

    it("should not allow end proposals process if there are no proposals", async function () {
      try {
        await votingInstance.registerVoter(account1);

        await votingInstance.startProposalsRegistrations({ from: administrator });
        await votingInstance.endProposalsRegistrations({ from: administrator });
        assert.isTrue(false);
      }
      catch (e: any) {
        assert.equal(e.name, 'Error', 'Expecting error');
        assert.include(e.stack, 'There must be at least 1 proposal registered before ending the proposal registration process', 'Expecting no proposal error');
      }
    });

    it("should not allow not registered voter to make proposal", async function () {
      try {
        await votingInstance.registerVoter(account1, { from: administrator });

        await votingInstance.startProposalsRegistrations({ from: administrator });

        await votingInstance.makeProposal('Proposal 1', {from: account2});
        assert.isTrue(false);
      }
      catch (e: any) {
        assert.equal(e.name, 'Error', 'Expecting error');
        assert.include(e.stack, 'You must be a registered voter', 'Expecting registered voter requirement error');
      }
    });

    it("should not allow not registered voter to vote for a proposal", async function () {
      try {
        await votingInstance.registerVoter(account1, { from: administrator });

        await votingInstance.startProposalsRegistrations({ from: administrator });

        await votingInstance.makeProposal('Proposal 1', {from: account1});

        await votingInstance.endProposalsRegistrations({ from: administrator });

        await votingInstance.startVotingSession({ from: administrator });

        await votingInstance.voteForProposal(0, {from: account2});

        assert.isTrue(false);
      }
      catch (e: any) {
        assert.equal(e.name, 'Error', 'Expecting error');
        assert.include(e.stack, 'You must be a registered voter', 'Expecting registered voter requirement error');
      }
    });

    it("should not allow multiple votes for the same voter", async function () {
      try {
        await votingInstance.registerVoter(account1, { from: administrator });

        await votingInstance.startProposalsRegistrations({ from: administrator });

        await votingInstance.makeProposal('Proposal 1', {from: account1});

        await votingInstance.endProposalsRegistrations({ from: administrator });

        await votingInstance.startVotingSession({ from: administrator });

        await votingInstance.voteForProposal(0, {from: account1});
        await votingInstance.voteForProposal(0, {from: account1});

        assert.isTrue(false);
      }
      catch (e: any) {
        assert.equal(e.name, 'Error', 'Expecting error');
        assert.include(e.stack, 'You already voted for a proposal', 'Expecting already voted error');
      }
    });

    // functional tests.
    it("Should designate no winner when there is no votes", async function() {
      await votingInstance.registerVoter(account1,{ from: administrator });
      await votingInstance.registerVoter(account2),{ from: administrator };
      await votingInstance.registerVoter(account3,{ from: administrator });
      await votingInstance.registerVoter(account4,{ from: administrator });

      await votingInstance.startProposalsRegistrations({ from: administrator });

      await votingInstance.makeProposal('Proposal 1', {from: account1});
      await votingInstance.makeProposal('Proposal 2', {from: account1});
      await votingInstance.makeProposal('Proposal 3', {from: account2});
      await votingInstance.makeProposal('Proposal 4', {from: account3});
      await votingInstance.makeProposal('Proposal 5', {from: account3});
      await votingInstance.makeProposal('Proposal 6', {from: account4});

      await votingInstance.endProposalsRegistrations({ from: administrator });

      await votingInstance.startVotingSession({ from: administrator });

      await votingInstance.endVotingSession({ from: administrator });

      await votingInstance.countVotes({from: administrator});

      const winners = await votingInstance.getWinner({from: account1});

      assert.equal(winners.length, 0, 'Should designate no winner');
    });

    it("Should designate winner of proposal 1", async function() {
      await votingInstance.registerVoter(account1, { from: administrator });
      await votingInstance.registerVoter(account2, { from: administrator });
      await votingInstance.registerVoter(account3, { from: administrator });

      await votingInstance.startProposalsRegistrations({ from: administrator });

      await votingInstance.makeProposal('Proposal 1', {from: account1});
      await votingInstance.makeProposal('Proposal 2', {from: account1});
      await votingInstance.makeProposal('Proposal 3', {from: account2});
      await votingInstance.makeProposal('Proposal 4', {from: account3});
      await votingInstance.makeProposal('Proposal 5', {from: account3});

      await votingInstance.endProposalsRegistrations({ from: administrator });

      await votingInstance.startVotingSession({ from: administrator });

      await votingInstance.voteForProposal(0, {from: account1});
      await votingInstance.voteForProposal(0, {from: account2});
      await votingInstance.voteForProposal(3, {from: account3});

      await votingInstance.endVotingSession({ from: administrator });

      await votingInstance.countVotes({from: administrator});

      const winners = await votingInstance.getWinner({from: account1});

      assert.equal(winners.length, 1, 'Should designate only 1 winner');
      assert.equal(winners[0][0], 'Proposal 1', 'Should designate proposal 1 as winner');
      assert.equal(parseInt(winners[0][1]), 2, 'Proposal 1 should have 2 votes');
    });

    it("Should designate proposals 1 and 4 as winners", async function() {
      await votingInstance.registerVoter(account1, { from: administrator });
      await votingInstance.registerVoter(account2, { from: administrator });
      await votingInstance.registerVoter(account3, { from: administrator });
      await votingInstance.registerVoter(account4, { from: administrator });

      await votingInstance.startProposalsRegistrations({ from: administrator });

      await votingInstance.makeProposal('Proposal 1', {from: account1});
      await votingInstance.makeProposal('Proposal 2', {from: account1});
      await votingInstance.makeProposal('Proposal 3', {from: account2});
      await votingInstance.makeProposal('Proposal 4', {from: account3});
      await votingInstance.makeProposal('Proposal 5', {from: account3});
      await votingInstance.makeProposal('Proposal 6', {from: account4});

      await votingInstance.endProposalsRegistrations({ from: administrator });

      await votingInstance.startVotingSession({ from: administrator });

      await votingInstance.voteForProposal(0, {from: account1});
      await votingInstance.voteForProposal(0, {from: account2});
      await votingInstance.voteForProposal(3, {from: account3});
      await votingInstance.voteForProposal(3, {from: account4});

      await votingInstance.endVotingSession({ from: administrator });

      await votingInstance.countVotes({from: administrator});

      const winners = await votingInstance.getWinner({from: account1});

      assert.equal(winners.length, 2, 'Should designate 2 draw winners');
      assert.equal(winners[0][0], 'Proposal 1', 'Should designate proposal 1 as winner');
      assert.equal(parseInt(winners[0][1]), 2, 'Proposal 1 should have 2 votes');
      assert.equal(winners[1][0], 'Proposal 4', 'Should designate proposal 4 as winner');
      assert.equal(parseInt(winners[1][1]), 2, 'Proposal 4 should have 2 votes');
    });
  });
});

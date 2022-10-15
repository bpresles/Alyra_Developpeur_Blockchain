// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * Simple voting system for small organizations.
 * 
 * Version 0.2 by Bertrand Presles of Alyra - Rinkeby.
 */
contract Voting is Ownable {
    // Voter details.
    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint votedProposalId;
    }

    // Proposal details.
    struct Proposal {
        string description;
        uint voteCount;
    }

    // Elections status.
    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    // Whitelist of registered voters
    mapping(address => Voter) private registeredVoters;

    // We keeps voters addresses to be able to reset the map.
    address[] private registeredVotersAddresses;

    // Proposals list. Array indexed are used as proposal ids.
    Proposal[] private proposals;

    // Keeping the current status.
    WorkflowStatus private currentStatus;

    // Winning proposals that can be viewed by anyone.
    uint[] private winningProposalsIds;

    // Count the total number of votes for control prupose.
    uint totalNbVotes;

    // Events.
    event VoterRegistered(address voterAddress);
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted(address voter, uint proposalId);
    event UniqueWinner(uint proposalId);
    event DrawResult(uint[] proposalsIds);

    /** 
     * Modifiers used to restrict functions to registered voters.
     */
    modifier onlyRegisteredVoter {
        require(registeredVoters[msg.sender].isRegistered, "You must be a registered voter.");
        _;
    }

    /** 
     * Modifiers used to restrict functions to registered voters or owner.
     */
    modifier onlyRegisteredVoterOrOwner {
        require(registeredVoters[msg.sender].isRegistered || msg.sender == owner(), "You must be a registered voter or owner.");
        _;
    }

    /**
     * Utility method to switch status.
     * 
     * @param _previousStatus WorkFlowStatus The previous status before the status change.
     * @param _newStatus WorkFlowStatus The new status to switch to.
     * 
     * Emits a {WorkflowStatusChange} event.
     */
    function updateWorkflowStatus(WorkflowStatus _previousStatus, WorkflowStatus _newStatus) private {
        currentStatus = _newStatus;
        emit WorkflowStatusChange(_previousStatus, _newStatus);
    }

    /**
     * Returns whether a proposal has already been proposed.
     *
     * @param _description string Proposal description.
     *
     * @return bool Returns true if the proposal exists, false otherwise.
     */
    function _proposalAlreadyExists(string calldata _description) private view returns(bool) {
        for (uint i = 0; i < proposals.length; i++) {
            if ((keccak256(abi.encodePacked((_description))) == keccak256(abi.encodePacked((proposals[i].description))))) {
                return true;
            }
        }

        return false;
    }

    /**
     * Registers a new voter. 
     * 
     * Only accessing to contract owner.
     * 
     * @param _voterAddr address The voter address to register.
     * 
     * Emits a {WorkflowStatusChange} event.
     */
    function registerVoter(address _voterAddr) external onlyOwner {
        require(currentStatus == WorkflowStatus.RegisteringVoters, "Current status doesn't allow new voter registration.");
        require(_voterAddr != owner(), "The administrator can't register himself as voter.");    
        require(!registeredVoters[_voterAddr].isRegistered, "Voter already registered.");   

        registeredVoters[_voterAddr] = Voter(true, false, 0);
        registeredVotersAddresses.push(_voterAddr);

        emit VoterRegistered(_voterAddr);
    }

    /**
     * Start the proposals registration process.
     * 
     * Only accessible to contract owner.
     * 
     * Emits a {WorkflowStatusChange} event.
     */
    function startProposalsRegistrations() external onlyOwner {
        require(currentStatus == WorkflowStatus.RegisteringVoters, "Current status doesn't allow to start the proposals registations.");
        require(registeredVotersAddresses.length > 1, "There is not enough voters registered. There must be at least 2 voters to start the process.");

        updateWorkflowStatus(currentStatus, WorkflowStatus.ProposalsRegistrationStarted);
    }

    /**
     * End the proposals registration process.
     * 
     * Only accessible to contract owner.
     * 
     * Emits a {WorkflowStatusChange} event.
     */
    function endProposalsRegistrations() external onlyOwner {
        require(currentStatus == WorkflowStatus.ProposalsRegistrationStarted, "Current status doesn't allow to end the proposals registations");
        require(proposals.length > 1, "There are not enough proposals. To have a meaning for the vote, there must be at least 2 proposals.");

        updateWorkflowStatus(currentStatus, WorkflowStatus.ProposalsRegistrationEnded);
    }

    /**
     * Start the voting session.
     * 
     * Only accessible to contract owner.
     * 
     * Emits a {WorkflowStatusChange} event.
     */
    function startVotingSession() external onlyOwner {
        require(currentStatus == WorkflowStatus.ProposalsRegistrationEnded, "Current status doesn't allow to start the voting session.");
        
        updateWorkflowStatus(currentStatus, WorkflowStatus.VotingSessionStarted);
    }

    /**
     * End the voting session.
     * 
     * Only accessible to contract owner.
     * 
     * Emits a {WorkflowStatusChange} event.
     */
    function endVotingSession() external onlyOwner {
        require(currentStatus == WorkflowStatus.VotingSessionStarted, "Current status doesn't allow to end the voting session.");
        require(totalNbVotes > 1, "There should be more than 1 vote before the voting session can be ended.");

        updateWorkflowStatus(currentStatus, WorkflowStatus.VotingSessionEnded);
    }

    /**
     * Allows a voter to register a proposal
     * 
     * Only accessible to registered voters.
     *
     * @param _description string calldata The proposal description.
     * 
     * Emits a {ProposalRegistered} event.
     */
    function makeProposal(string calldata _description) external onlyRegisteredVoter {
        require(currentStatus == WorkflowStatus.ProposalsRegistrationStarted, "Proposals registrations are not opened.");
        require(!_proposalAlreadyExists(_description), "This proposal has already been submitted.");

        Proposal memory proposal = Proposal(_description, 0);
        proposals.push(proposal);

        emit ProposalRegistered(proposals.length-1);
    }

    /**
     * Allows voters to see the list of proposals.
     * 
     * Only accessible to registered voters. Can only be consulted if the proposal process is already finished.
     *
     * @return Proposal[] The proposals list.
     */
    function getProposalsList() external view onlyRegisteredVoterOrOwner returns(Proposal[] memory) {
        require(currentStatus >= WorkflowStatus.ProposalsRegistrationEnded, "Proposals registrations are not finished.");

        return proposals;
    }

    /**
     * Allows voters to get a proposal details.
     * 
     * Only accessible to registered voters. 
     * Only available if the proposal process ended.
     *
     * @param _proposalId uint Id of the proposal to look up.     
     *
     * @return Proposal The proposal associated to the passed id.
     */
    function getProposalDetails(uint _proposalId) external view onlyRegisteredVoterOrOwner returns(Proposal memory) {
        require(currentStatus >= WorkflowStatus.ProposalsRegistrationEnded, "Proposals registrations are not finished.");

        return proposals[_proposalId];
    }

    /**
     * Allows a voter to vote for a proposal.
     * 
     * Only accessible to registered voters. Voters can only vote once.
     *
     * @param _proposalId uint The proposal id.
     * 
     * Emits a {Voted} event.
     */
    function voteForProposal(uint _proposalId) external onlyRegisteredVoter {
        require(currentStatus == WorkflowStatus.VotingSessionStarted, "Voting session has not started.");
        require(!registeredVoters[msg.sender].hasVoted, "You already voted for a proposal.");

        proposals[_proposalId].voteCount++;
        registeredVoters[msg.sender].hasVoted = true;
        totalNbVotes++;
        
        emit Voted(msg.sender, _proposalId);
    }

    /**
     * Counts the votes and determine the most voted winning proposal. 
     * 
     * Only accessible to contract owner.
     * 
     * Emits a {WorkflowStatusChange} event.
     */
    function countVotes() external onlyOwner {
        require(currentStatus == WorkflowStatus.VotingSessionEnded, "Voting session isn't finished.");

        uint lastGreatestNbOfVotes = 0;
        for (uint _proposalId = 0; _proposalId < proposals.length; _proposalId++) {
            // A new most voted proposal has been identified.
            if (proposals[_proposalId].voteCount > lastGreatestNbOfVotes) {
                lastGreatestNbOfVotes = proposals[_proposalId].voteCount;

                // As the proposal has more vote than any previous ones, we delete the
                // previous most voted proposals and push the new one.
                delete winningProposalsIds;
                winningProposalsIds.push(_proposalId);
            }
            else if (proposals[_proposalId].voteCount == lastGreatestNbOfVotes) {
                // We add any new proposal having the exact same count of votes
                // than the greatestNbOfVotes yet.
                winningProposalsIds.push(_proposalId);
            }
        }

        updateWorkflowStatus(currentStatus, WorkflowStatus.VotesTallied);

        // Emit events indicating if a clear winner has been determined or if the result is a draw.
        if (winningProposalsIds.length > 1) {
            emit DrawResult(winningProposalsIds);
        } else {
            emit UniqueWinner(winningProposalsIds[0]);
        }
    }

    /**
     * Allows anyone to get the winning proposal(s).
     * 
     * @return Proposals[] Winning proposal(s).
     */
    function getWinner() external view returns(uint[] memory) {
        require(currentStatus == WorkflowStatus.VotesTallied, "Votes hasn't been counted yet.");

        return winningProposalsIds;
    }

    /**
     * Function to reset the voting process all together.
     */
    function resetVotingProcess() external onlyOwner {
        delete currentStatus;
        delete proposals;
        for (uint i = 0; i < registeredVotersAddresses.length; i++) {
            delete registeredVoters[registeredVotersAddresses[i]];
        }
        delete registeredVotersAddresses;
        delete winningProposalsIds;
        delete totalNbVotes;
    }
}

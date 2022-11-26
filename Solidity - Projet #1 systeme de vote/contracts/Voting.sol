// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * Simple voting system for small organizations.
 * 
 * @title A simple voting contract
 * @author Bertrand Presles - Alyra - Rinkeby
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
    mapping(address => Voter) private _registeredVoters;

    // We keeps voters addresses to be able to reset the map.
    address[] private _registeredVotersAddresses;

    // Proposals list. Array indexed are used as proposal ids.
    Proposal[] private _proposals;

    // Keeping the current status.
    WorkflowStatus private _currentStatus;

    // Winning Proposals.
    Proposal[] private _winningProposals;

    // Workflow events.
    event VoterRegistered(address voterAddress);
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted(address voter, uint proposalId);

    // Results events
    event NoWinner();
    event UniqueWinner(Proposal proposalId);
    event DrawWinners(Proposal[] proposalsIds);

    /** 
     * Modifiers used to restrict functions to registered voters.
     */
    modifier onlyRegisteredVoter {
        require(_registeredVoters[msg.sender].isRegistered, "You must be a registered voter.");
        _;
    }

    /** 
     * Modifiers used to restrict functions to registered voters or owner.
     */
    modifier onlyRegisteredVoterOrOwner {
        require(_registeredVoters[msg.sender].isRegistered || msg.sender == owner(), "You must be a registered voter or owner.");
        _;
    }

    /**
     * Utility method to switch status.
     * 
     * @param previousStatus WorkFlowStatus The previous status before the status change.
     * @param newStatus WorkFlowStatus The new status to switch to.
     * 
     * Emits a {WorkflowStatusChange} event.
     */
    function _updateWorkflowStatus(WorkflowStatus previousStatus, WorkflowStatus newStatus) private {
        _currentStatus = newStatus;
        emit WorkflowStatusChange(previousStatus, newStatus);
    }

    /**
     * Returns whether a proposal has already been proposed.
     *
     * @param description string Proposal description.
     *
     * @return bool Returns true if the proposal exists, false otherwise.
     */
    function _proposalAlreadyExists(string calldata description) private view returns(bool) {
        for (uint i = 0; i < _proposals.length; i++) {
            if ((keccak256(abi.encodePacked((description))) == keccak256(abi.encodePacked((_proposals[i].description))))) {
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
     * @param voterAddr address The voter address to register.
     * 
     * Emits a {WorkflowStatusChange} event.
     */
    function registerVoter(address voterAddr) external onlyOwner {
        require(_currentStatus == WorkflowStatus.RegisteringVoters, "Current status doesn't allow new voter registration."); 
        require(!_registeredVoters[voterAddr].isRegistered, "Voter already registered.");   

        _registeredVoters[voterAddr] = Voter(true, false, 0);
        _registeredVotersAddresses.push(voterAddr);

        emit VoterRegistered(voterAddr);
    }

    /**
     * Start the proposals registration process.
     * 
     * Only accessible to contract owner.
     * 
     * Emits a {WorkflowStatusChange} event.
     */
    function startProposalsRegistrations() external onlyOwner {
        require(_currentStatus == WorkflowStatus.RegisteringVoters, "Current status doesn't allow to start the _proposals registations.");
        require(_registeredVotersAddresses.length > 0, "There must be at least 1 voter to start the proposal registration process.");

        _updateWorkflowStatus(_currentStatus, WorkflowStatus.ProposalsRegistrationStarted);
    }

    /**
     * End the proposals registration process.
     * 
     * Only accessible to contract owner.
     * 
     * Emits a {WorkflowStatusChange} event.
     */
    function endProposalsRegistrations() external onlyOwner {
        require(_currentStatus == WorkflowStatus.ProposalsRegistrationStarted, "Current status doesn't allow to end the _proposals registations");
        require(_proposals.length > 0, "There must be at least 1 proposal registered before ending the proposal registration process.");

        _updateWorkflowStatus(_currentStatus, WorkflowStatus.ProposalsRegistrationEnded);
    }

    /**
     * Start the voting session.
     * 
     * Only accessible to contract owner.
     * 
     * Emits a {WorkflowStatusChange} event.
     */
    function startVotingSession() external onlyOwner {
        require(_currentStatus == WorkflowStatus.ProposalsRegistrationEnded, "Current status doesn't allow to start the voting session.");
        
        _updateWorkflowStatus(_currentStatus, WorkflowStatus.VotingSessionStarted);
    }

    /**
     * End the voting session.
     * 
     * Only accessible to contract owner.
     * 
     * Emits a {WorkflowStatusChange} event.
     */
    function endVotingSession() external onlyOwner {
        require(_currentStatus == WorkflowStatus.VotingSessionStarted, "Current status doesn't allow to end the voting session.");

        _updateWorkflowStatus(_currentStatus, WorkflowStatus.VotingSessionEnded);
    }

    /**
     * Allows a voter to register a proposal
     * 
     * Only accessible to registered voters.
     *
     * @param description string calldata The proposal description.
     * 
     * Emits a {ProposalRegistered} event.
     */
    function makeProposal(string calldata description) external onlyRegisteredVoter {
        require(_currentStatus == WorkflowStatus.ProposalsRegistrationStarted, "Proposals registrations are not opened.");
        require(!_proposalAlreadyExists(description), "This proposal has already been submitted.");

        Proposal memory proposal = Proposal(description, 0);
        _proposals.push(proposal);

        emit ProposalRegistered(_proposals.length-1);
    }

    /**
     * Allows voters to see the list of _proposals.
     * 
     * Only accessible to registered voters. Can only be consulted if the proposal process is already finished.
     *
     * @return Proposal[] The _proposals list.
     */
    function getProposalsList() external view onlyRegisteredVoterOrOwner returns(Proposal[] memory) {
        require(_currentStatus >= WorkflowStatus.ProposalsRegistrationEnded, "Proposals registrations are not finished.");

        return _proposals;
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
        require(_currentStatus >= WorkflowStatus.ProposalsRegistrationEnded, "Proposals registrations are not finished.");

        return _proposals[_proposalId];
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
        require(_currentStatus == WorkflowStatus.VotingSessionStarted, "Voting session has not started.");
        require(!_registeredVoters[msg.sender].hasVoted, "You already voted for a proposal.");

        _proposals[_proposalId].voteCount++;
        _registeredVoters[msg.sender].hasVoted = true;
        
        emit Voted(msg.sender, _proposalId);
    }

    /**
     * Counts the votes and determine the most voted winning proposal. 
     * 
     * Only accessible to contract owner.
     * 
     * Emits a {WorkflowStatusChange} event.
     * Emits a {DrawResult} or {UniqueWinner} event.
     */
    function countVotes() external onlyOwner {
        require(_currentStatus == WorkflowStatus.VotingSessionEnded, "Voting session isn't finished.");

        uint lastHighestNbOfVotes = 0;
        for (uint _proposalId = 0; _proposalId < _proposals.length; _proposalId++) {
            // A new most voted proposal has been identified.
            if (_proposals[_proposalId].voteCount > lastHighestNbOfVotes) {
                lastHighestNbOfVotes = _proposals[_proposalId].voteCount;

                // As the proposal has more vote than any previous ones, we delete the
                // previous most voted proposals and push the new one.
                delete _winningProposals;
                _winningProposals.push(_proposals[_proposalId]);
            }
            else if (_proposals[_proposalId].voteCount > 0 && _proposals[_proposalId].voteCount == lastHighestNbOfVotes) {
                // We add any new proposal having the exact same count of votes
                // than the lastHighestNbOfVotes yet.
                _winningProposals.push(_proposals[_proposalId]);
            }
        }

        _updateWorkflowStatus(_currentStatus, WorkflowStatus.VotesTallied);

        // Emit events indicating if a clear winner has been determined or if the result is a draw.
        if (_winningProposals.length == 0) {
            emit NoWinner();
        } else if(_winningProposals.length > 1) {
            emit DrawWinners(_winningProposals);
        } else {
            emit UniqueWinner(_winningProposals[0]);
        }
    }

    /**
     * Allows anyone to get the winning proposal(s) details.
     * 
     * @return Proposal[] Winning proposal(s).
     */
    function getWinner() external view returns(Proposal[] memory) {
        require(_currentStatus == WorkflowStatus.VotesTallied, "Votes hasn't been counted yet.");

        return _winningProposals;
    }

    /**
     * Function to reset the voting process all together.
     */
    function resetVotingProcess() external onlyOwner {
        delete _currentStatus;
        delete _proposals;
        for (uint i = 0; i < _registeredVotersAddresses.length; i++) {
            delete _registeredVoters[_registeredVotersAddresses[i]];
        }
        delete _registeredVotersAddresses;
        delete _winningProposals;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

// @notice This contract allows people to fund it and withdraw funds through request workflow
contract MultiSigWallet {
    enum RequestState {
        Active,
        Approved,
        Rejected,
        Disputed,
        Executed
    }

    enum VoteOption {
        For,
        Against
    }

    struct Vote {
        bool hasVoted;
        VoteOption vote;
    }

    struct Request {
        address owner;
        uint256 amount;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 requestedAt;
        RequestState status;
        bool spent;
        mapping(address => Vote) votes;
    }

    uint256 public reqCounter;
    uint256 public participantsCount;
    mapping(uint256 => Request) public requests;
    mapping(uint256 => Vote) private votes;
    mapping(address => uint256) public deposits;
    mapping(address => uint256) public addrSpent;
    mapping(address => bool) public participants;

    event Deposit(address indexed depositor, uint256 indexed amount);
    event Requested(address indexed requestor, uint256 indexed amount);
    event Voted(
        uint256 indexed requestNumber,
        address indexed voter,
        VoteOption vote,
        RequestState status
    );
    event ChangeVote(address indexed voter, VoteOption newVote);
    event Withdraw(address indexed spender, uint256 indexed amount);

    // @notice Storing users in participants mapping
    // @dev payable at deployment
    constructor(address[] memory _participants) payable {
        for (uint i = 0; i < _participants.length; i++) {
            participants[_participants[i]] = true;
            participantsCount++;
        }
    }

    // @notice Only addresses that are part of participants mapping
    modifier onlyParticipant() {
        require(participants[msg.sender], "You are not participant");
        _;
    }

    // @notice Allow ETH deposits
    // @dev payable function, onlyParticipant modifier
    function depositFunds() external payable onlyParticipant {
        deposits[msg.sender] = msg.value;
    }

    // @notice Allow participant to request withdraw
    // @dev Store request in requests mapping, onlyParticipant modifier
    // @param _amount to withdraw
    function requestWithdraw(uint256 _amount) external onlyParticipant {
        Request storage request = requests[reqCounter];
        request.owner = msg.sender;
        request.amount = _amount;
        request.status = RequestState.Active;
        request.votes[msg.sender].hasVoted = true;
        request.votes[msg.sender].vote = VoteOption.For;
        request.spent = false;
        request.requestedAt = block.timestamp;
        reqCounter++;

        emit Requested(msg.sender, _amount);
    }

    // @notice Allow spender to withdraw
    // @dev requires request to be in Approved state, enough ether in balance of contract and to be request owner
    function withdraw(uint256 _id) external {
        Request storage request = requests[_id];
        require(
            getBalance() >= request.amount,
            "Insufficient contract balance"
        );
        require(request.owner == msg.sender, "Not owner of request");
        require(
            _getRequestStatus(request) == RequestState.Approved,
            "Rejected or spent"
        );

        request.spent = true;
        addrSpent[msg.sender] = request.amount;

        (bool sent, ) = msg.sender.call{value: request.amount}("");
        require(sent, "Transaction failed");

        emit Withdraw(msg.sender, request.amount);
    }

    // @notice Allow participants to vote on request
    // @dev requires only users that have not voted yet, request is in Active Status (within 24h from request creation) and be participant
    // @params _id of request, _vote to cast
    function castVote(uint256 _id, VoteOption _vote) external onlyParticipant {
        Request storage request = requests[_id];
        require(request.votes[msg.sender].hasVoted == false, "Already voted");
        require(
            _getRequestStatus(request) == RequestState.Active,
            "Voting closed"
        );

        request.votes[msg.sender] = Vote({hasVoted: true, vote: _vote});

        if (_vote == VoteOption.For) {
            request.votesFor++;
        } else {
            request.votesAgainst++;
        }

        emit Voted(_id, msg.sender, _vote, request.status);
    }

    // @notice Allow voters to change their vote
    // @dev Only if user has voted already, state to is Active (within 24h from request creation)
    // @param _id of request
    function changeVote(uint256 _id) external {
        Request storage request = requests[_id];
        require(
            request.votes[msg.sender].hasVoted,
            "Have not voted/Not participant"
        );
        require(
            _getRequestStatus(request) == RequestState.Active,
            "Voting closed"
        );

        // @notice switch votes and amend vote calculations
        if (request.votes[msg.sender].vote == VoteOption.For) {
            request.votesFor--;
            request.votesAgainst++;
            request.votes[msg.sender].vote = VoteOption.Against;
        } else {
            request.votesFor++;
            request.votesAgainst--;
            request.votes[msg.sender].vote = VoteOption.For;
        }

        emit ChangeVote(msg.sender, request.votes[msg.sender].vote);
    }

    // @notice Get Wallet balance
    // @return Balance of contract
    function getBalance() public view returns (uint256 balance) {
        balance = address(this).balance;
    }

    // @notice Get total spent by address
    // @dev _participant of wallet
    // @return Spent amount
    function getSpentByAddr(
        address _participant
    ) external view returns (uint256 spent) {
        spent = addrSpent[_participant];
    }

    // @notice Get the total deposited by address
    // @dev _participant of wallet
    // @return Deposited amount
    function getDepositsByAddr(
        address _participant
    ) external view returns (uint256 deposit) {
        deposit = deposits[_participant];
    }

    // @notice Get the status of request
    // @param _id the id of request
    function getRequestStatus(
        uint256 _id
    ) external view returns (RequestState status) {
        Request storage request = requests[_id];
        status = _getRequestStatus(request);
    }

    // @notice Internal function to calculate Status for request
    // @dev A request to pass it requires 50% or above of participants to votes - For
    // @param _request The request selected in other functions
    // @return Status of request
    function _getRequestStatus(
        Request storage _request
    ) internal view returns (RequestState status) {
        // Total votes
        uint256 votesCount = _request.votesAgainst + _request.votesFor;
        // Required votes for request to pass - 50% of participants
        uint256 requiredVotes = participantsCount / 2;

        // Status is Active within 24h from request
        if (block.timestamp < _request.requestedAt + 24 hours) {
            status = RequestState.Active;
            // Status is Approved once votes For are above 50%
        } else if (requiredVotes <= _request.votesFor) {
            status = RequestState.Approved;
            // Status is Rejected when votes Against are above 50%
            // OR when total votes are less than 50%
        } else if (
            requiredVotes <= _request.votesAgainst || votesCount < requiredVotes
        ) {
            status = RequestState.Rejected;
            // Status is Disputed when For/ Against have equal number
        } else {
            status = RequestState.Disputed;
        }

        // Status is Executed once funds are withdrawn
        if (_request.spent == true) {
            status = RequestState.Executed;
        }
    }
}
